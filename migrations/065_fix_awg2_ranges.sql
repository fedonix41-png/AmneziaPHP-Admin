-- Fix H1-H4 parameters for awg2 to be single integers instead of ranges.
-- Ranges in awg0.conf break awg-quick and cause server to default to 0,
-- while the client picks a random number from the range, causing handshake failure
-- and no traffic exchange.

UPDATE protocol_variables pv
SET default_value = CASE pv.variable_name
    WHEN 'H1' THEN '1443912531'
    WHEN 'H2' THEN '1984025557'
    WHEN 'H3' THEN '2145217268'
    WHEN 'H4' THEN '2146790761'
    ELSE pv.default_value
END
FROM protocols p
WHERE p.id = pv.protocol_id
  AND p.slug = 'awg2'
  AND pv.variable_name IN ('H1', 'H2', 'H3', 'H4');

UPDATE vpn_servers
SET awg_params = '{"JC":5,"JMIN":10,"JMAX":50,"S1":51,"S2":125,"S3":13,"S4":9,"H1":"1443912531","H2":"1984025557","H3":"2145217268","H4":"2146790761","I1":"<r 2><b 0x858000010001000000000669636c6f756403636f6d0000010001c00c000100010000105a00044d583737>","I2":"","I3":"","I4":"","I5":""}'
WHERE install_protocol = 'awg2';

UPDATE protocols
SET install_script = REPLACE(
    REPLACE(
        REPLACE(
            REPLACE(install_script, 
            'H1_VAL="1443912531-1981073285"', 'H1_VAL="1443912531"'),
        'H2_VAL="1984025557-2135018048"', 'H2_VAL="1984025557"'),
    'H3_VAL="2145217268-2146643749"', 'H3_VAL="2145217268"'),
'H4_VAL="2146790761-2146860793"', 'H4_VAL="2146790761"')
WHERE slug = 'awg2';
