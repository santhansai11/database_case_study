"""Validate the assignment in a disposable MySQL 8 server, never an existing DB.

Usage: python tests/validate_mysql.py --mysql-bin "C:/Program Files/MySQL/MySQL Server 8.0/bin"
Uses only Python's standard library. The temporary instance binds to localhost,
uses a fresh data directory, and is shut down and removed after the checks.
"""

import argparse
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mysql-bin', required=True, type=Path)
    args = parser.parse_args()
    suffix = '.exe' if os.name == 'nt' else ''
    binary = lambda name: str(args.mysql_bin.resolve() / (name + suffix))
    script = (Path(__file__).resolve().parents[1] / 'Q3_two_wheeler_db.sql').read_text(encoding='utf-8')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    passed = 0

    def run(command, **kwargs):
        return subprocess.run(command, capture_output=True, text=True,
                              creationflags=flags, timeout=60, **kwargs)

    with tempfile.TemporaryDirectory(prefix='two-wheeler-validation-') as directory:
        data = Path(directory) / 'data'
        data.mkdir()
        init = run([binary('mysqld'), '--no-defaults', '--initialize-insecure',
                    f'--datadir={data}', '--console'])
        if init.returncode:
            raise RuntimeError(init.stderr)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        connection = ['--no-defaults', '--protocol=TCP', '--host=127.0.0.1',
                      f'--port={port}', '--user=root']
        client = [binary('mysql'), *connection, '--batch', '--skip-column-names']
        with (Path(directory) / 'server.log').open('w') as log:
            server = subprocess.Popen([binary('mysqld'), '--no-defaults',
                f'--datadir={data}', '--bind-address=127.0.0.1', f'--port={port}',
                '--mysqlx=OFF', '--skip-log-bin', '--innodb-buffer-pool-size=64M',
                '--console'], stdout=log, stderr=log, creationflags=flags)
            try:
                for _ in range(60):
                    if server.poll() is not None:
                        raise RuntimeError((Path(directory) / 'server.log').read_text())
                    if run(client + ['-e', 'SELECT 1']).returncode == 0:
                        break
                    time.sleep(0.5)
                else:
                    raise RuntimeError('Temporary MySQL did not become ready')
                loaded = run(client, input=script)
                if loaded.returncode:
                    raise AssertionError(loaded.stderr)
                print('PASS: full SQL script, including all six sample queries', flush=True)
                passed += 1

                def check(name, sql, expected=None, error=None):
                    nonlocal passed
                    # Each check uses a separate connection and rolls back mutations.
                    result = run(client + ['two_wheeler_db'],
                                 input='START TRANSACTION;\n' + sql + '\nROLLBACK;')
                    if error is not None:
                        if result.returncode == 0 or f'ERROR {error} ' not in result.stderr:
                            raise AssertionError(f'{name}: expected MySQL error {error}, got {result.stdout} {result.stderr}')
                    elif result.returncode or (expected is not None and result.stdout.strip() != expected):
                        raise AssertionError(f'{name}: expected {expected!r}, got {result.stdout!r} {result.stderr}')
                    print('PASS:', name, flush=True)
                    passed += 1

                check('18 tables', "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='two_wheeler_db';", '18')
                tables = re.findall(r'CREATE TABLE (\w+)', script)
                check('every table has sample records', '\n'.join(
                    f'SELECT COUNT(*) > 0 FROM {table};' for table in tables), '\n'.join(['1'] * 18))
                samples = script.split('-- SAMPLE QUERIES demonstrating', 1)[1].split('\n', 1)[1]
                samples = re.sub(r'--[^\n]*', '', samples)
                queries = [s.strip() + ';' for s in samples.split(';') if s.strip()]
                if len(queries) != 6:
                    raise AssertionError('Expected six sample queries')
                # Assert query results independently of output row order.
                expected = [
                    {'MAT447000D4000001', 'MAT447000D4000002', 'MAT447000E5000001'},
                    {'EVM5000\t70200.00', 'EVX3000\t65100.00', 'ZMR2100\t55700.00', 'XSP160\t50200.00', 'SCT1100\t35900.00'},
                    {'1\tBharat Brakes Pvt Ltd\t2\t1', '2\tSunridges Tyres Ltd\t2\t1', '3\tVoltCells Energy Pvt Ltd\t2\t2', '4\tPrecision Drivetrain Co\t3\t2', '5\tOptiLight Systems\t2\t1'},
                    {'Bidadi EV Plant\tLi-Ion Battery Pack 3kWh\t35\t60'},
                    {'MAT447000A1000001\tX-Sport 160\t2026-09-10\tFree\t1250\t0.00\tJoseph Mathew'},
                ]
                for i, rows in enumerate(expected):
                    result = run(client + ['two_wheeler_db'], input=queries[i])
                    actual = result.stdout.strip().splitlines()
                    if result.returncode or set(actual) != rows or len(actual) != len(rows):
                        raise AssertionError(f'Sample {i + 1}: {result.stdout} {result.stderr}')
                    print(f'PASS: sample query {i + 1} expected rows', flush=True)
                    passed += 1
                result = run(client + ['two_wheeler_db'], input=queries[5])
                if result.returncode or len(result.stdout.strip().splitlines()) != 5:
                    raise AssertionError('Sales sample must return five rows')
                passed += 1
                print('PASS: sales sample returns five sales', flush=True)

                check('two unnumbered tyres in seed data', "SELECT COUNT(*) FROM vehicle_component WHERE vin='MAT447000A1000001' AND component_id=6 AND serial_no IS NULL;", '2')
                check('same type can come from two batches', "INSERT INTO vehicle_component(vin,component_id,batch_no,install_date,serial_no) VALUES ('MAT447000D4000001',3,'BAT3K-A118','2026-07-10','SECOND-BATTERY'); SELECT COUNT(DISTINCT batch_no) FROM vehicle_component WHERE vin='MAT447000D4000001' AND component_id=3;", '2')
                check('recall returns a VIN only once for repeated parts', queries[0].replace('BAT3K-A117', 'TYR-90B221'), 'MAT447000A1000001')
                check('negative sale price rejected', "UPDATE vehicle SET sale_price=-1 WHERE vin='MAT447000A1000001';", error=3819)
                check('zero sale price rejected', "UPDATE vehicle SET sale_price=0 WHERE vin='MAT447000A1000001';", error=3819)
                check('duplicate serial rejected on update', "UPDATE vehicle_component SET serial_no='ENG160-000781' WHERE vin='MAT447000A1000002' AND component_id=1;", error=1062)
                check('duplicate serial rejected on insert', "INSERT INTO vehicle_component(vin,component_id,batch_no,install_date,serial_no) VALUES ('MAT447000A1000003',1,'ENG160-B001','2026-06-18','ENG160-000781');", error=1062)
                check('serial uniqueness is scoped to component type', "UPDATE vehicle_component SET serial_no='ENG160-000781' WHERE vin='MAT447000A1000001' AND component_id=4;")
                check('delivery before ordering rejected', "UPDATE supply_order SET delivery_date='2020-01-01' WHERE po_id=1;", error=3819)
                check('same-day delivery allowed', "UPDATE supply_order SET delivery_date=order_date WHERE po_id=1;")
                check('negative order price rejected', 'UPDATE supply_order SET unit_price=-1 WHERE po_id=1;', error=3819)
                check('negative agreed lead time rejected', 'UPDATE supply_order SET agreed_lead_time_days=-1 WHERE po_id=1;', error=3819)
                check('electric type with petrol rejected', "UPDATE vehicle_model SET vehicle_type='Electric Scooter' WHERE model_code='XSP160';", error=3819)
                check('petrol type with electric fuel rejected', "UPDATE vehicle_model SET vehicle_type='Motorcycle' WHERE model_code='EVX3000';", error=3819)
                check('zero petrol engine capacity rejected', "UPDATE vehicle_model SET engine_capacity_cc=0 WHERE model_code='XSP160';", error=3819)
                check('NULL petrol engine capacity rejected', "UPDATE vehicle_model SET engine_capacity_cc=NULL WHERE model_code='XSP160';", error=3819)
                check('electric engine capacity rejected', "UPDATE vehicle_model SET engine_capacity_cc=160 WHERE model_code='EVX3000';", error=3819)
                performance = "SELECT SUM(CASE WHEN delivery_date IS NOT NULL AND DATEDIFF(delivery_date,order_date)<=agreed_lead_time_days THEN 1 ELSE 0 END) FROM supply_order WHERE supplier_id=1;"
                check('historical performance survives current lead-time change', performance + ' UPDATE supplies SET lead_time_days=1 WHERE supplier_id=1; ' + performance, '1\n1')
                check('sample performance query survives current lead-time change', 'UPDATE supplies SET lead_time_days=1 WHERE supplier_id=1; ' + queries[2].rstrip(';') + ' ORDER BY s.supplier_id;', '\n'.join(sorted(expected[2])))
                check('wrong component batch rejected', "UPDATE vehicle_component SET batch_no='BAT3K-A117' WHERE vin='MAT447000A1000001' AND component_id=1;", error=1452)
                check('sold without customer rejected', "UPDATE vehicle SET customer_id=NULL WHERE vin='MAT447000A1000001';", error=1644)
                check('sold without customer rejected on insert', "INSERT INTO vehicle(vin,model_code,plant_id,mfg_date,color,status,dealer_id,sale_date,sale_price) VALUES ('TEST-SOLD','XSP160',1,'2026-06-15','Red','Sold',1,'2026-07-02',125000);", error=1644)
                check('sale before manufacture rejected', "UPDATE vehicle SET sale_date='2020-01-01' WHERE vin='MAT447000A1000001';", error=3819)
                check('At-Dealer requires dealer', "UPDATE vehicle SET dealer_id=NULL WHERE vin='MAT447000A1000003';", error=1644)
                check('plant vehicle cannot have customer', "UPDATE vehicle SET customer_id=1 WHERE vin='MAT447000D4000003';", error=1644)
                check('unknown service employee allowed', 'UPDATE service_record SET emp_id=NULL WHERE service_id=1;')
                print(f'All {passed} checks passed.', flush=True)
            finally:
                try:
                    run([binary('mysqladmin'), *connection, 'shutdown'])
                finally:
                    try:
                        server.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        server.terminate()
                        server.wait(timeout=10)


if __name__ == '__main__':
    main()
