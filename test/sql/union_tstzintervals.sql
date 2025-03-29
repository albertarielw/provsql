\set ECHO none
\pset format unaligned
SET search_path TO provsql_test,provsql;

SET TIME ZONE 'UTC';
SET datestyle = 'iso';

DELETE FROM query_provenance;
CREATE TABLE test(id INT PRIMARY KEY);
SELECT add_provenance('test');

-- Test 1: test tuple valid time after insert, delete, update operations
INSERT INTO test (id) VALUES (1), (2), (3);
DELETE FROM test WHERE id = 2;
UPDATE test SET id = 4 WHERE id = 3;

-- set fixed tstzmultirange values for predictable result
UPDATE query_provenance
SET valid_time = CASE
  WHEN query_type = 'INSERT' THEN tstzmultirange(tstzrange('1970-01-01 00:00:00+00', NULL))
  WHEN query_type = 'DELETE' THEN tstzmultirange(tstzrange('1970-01-01 00:00:01+00', NULL))
  WHEN query_type = 'UPDATE' THEN tstzmultirange(tstzrange('1970-01-01 00:00:02+00', NULL))
  ELSE valid_time
END
WHERE query_type IN ('INSERT', 'DELETE', 'UPDATE');

SELECT create_provenance_mapping_view('time_validity_view', 'query_provenance', 'valid_time');
CREATE TABLE union_tstzintervals_result AS SELECT *, union_tstzintervals(provenance(),'time_validity_view') FROM test;
SELECT remove_provenance('union_tstzintervals_result');
SELECT * FROM union_tstzintervals_result;
DROP TABLE union_tstzintervals_result;

-- Test 2: test tuple valid time after undo operation
CREATE TABLE undo_result AS SELECT undo(provsql) FROM query_provenance WHERE query = 'DELETE FROM test WHERE id = 2;';
DROP TABLE undo_result;

-- set fixed tstzmultirange values for predictable result
UPDATE query_provenance
SET valid_time = tstzmultirange(tstzrange('1970-01-01 00:00:03+00', NULL))
WHERE query_type = 'UNDO';

SELECT create_provenance_mapping_view('time_validity_view', 'query_provenance', 'valid_time');
CREATE TABLE union_tstzintervals_result AS SELECT *, union_tstzintervals(provenance(),'time_validity_view') FROM test;
SELECT remove_provenance('union_tstzintervals_result');
SELECT * FROM union_tstzintervals_result;
DROP TABLE union_tstzintervals_result;

-- Test 3: insert token tracking/ logging into query_provenance table
CREATE TABLE query_provenance_result AS
SELECT query FROM query_provenance ORDER BY ts;
SELECT remove_provenance('query_provenance_result');
SELECT * FROM query_provenance_result;
DROP TABLE query_provenance_result;

DELETE FROM query_provenance;

DROP TABLE test;
