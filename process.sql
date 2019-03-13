CREATE or replace FUNCTION process(_tb1 regclass, town_name TEXT, town_id TEXT) 
RETURNS VOID AS
$func$
DECLARE
   city_name text := '文昌市';  -- assign at declaration
   city_code text := '469005';
BEGIN
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN sxm VARCHAR DEFAULT ' || city_name;
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN sxdm VARCHAR DEFAULT ' || city_code;
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN xzqhdm VARCHAR DEFAULT ' || town_id;
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN xzmc VARCHAR DEFAULT ' || town_name;
    EXECUTE 'ALTER TABLE ' || _tb1 || 'ALTER COLUMN geom TYPE geometry(MultiPolygon,4508) USING ST_Transform(ST_SetSRID( geom,4326 ), 4508)';
UPDATE 我负责的增量违建矢量文件
SET sfzgjsyd='同时落在总规建设用地内外'  
FROM lu_plan
WHERE
  ST_Overlaps(lu_plan.geom, 我负责的增量违建矢量文件.geom)
AND
  lu_plan.is_construc = '建设用地';
  
--  注意与word文档配合着完成这个查询过程
--  Query returned successfully: 10 rows affected, 550 msec execution time.
--  每次查询要记录这个信息，这个行数是满足查询条件的违法图斑的个数，
--  如果在一系列查询中这个数值都是0，那有可能是坐标系统不一致的缘故。
--  这个信息是word文档中第4节的第一个表格里面统计的依据，一定要记录

UPDATE 我负责的增量违建矢量文件
SET sfzgjsyd='完全落在总规建设用地内'  
FROM lu_plan
WHERE
  ST_Contains(lu_plan.geom, 我负责的增量违建矢量文件.geom)
AND
  lu_plan.is_construc = '建设用地';

-- Query returned successfully: 0 rows affected, 266 msec execution time.
END;
$func$
LANGUAGE plpgsql;
--select process('public.baoluo', '保罗镇', '469005000');
