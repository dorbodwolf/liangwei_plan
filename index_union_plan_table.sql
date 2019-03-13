-- deyu tian
CREATE or replace FUNCTION process() 
RETURNS VOID AS
$func$
DECLARE
   city_name varchar := '文昌市';  -- assign at declaration
   city_code text := '469005';
   plan_tbname text; -- 多规合一图层表名作为循环变量提前声明
   geom_srid integer; -- 多规合一图层的srid号预定义
   coord_dim integer; --
   inherent_dim integer; --
BEGIN
	FOR plan_tbname IN
      SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE'
      AND table_name LIKE 'merged%'
    LOOP
		-- 从多规导出的数据的坐标维度（4D）和列定义维度（2D）不一致，这里来强制转换
		EXECUTE format('SELECT DISTINCT ST_CoordDim(geom), ST_Dimension(geom) from %I', plan_tbname) INTO coord_dim, inherent_dim;
		IF coord_dim != inherent_dim THEN
		EXECUTE format('select ST_SRID(geom) from %I', plan_tbname) INTO geom_srid;
		EXECUTE format('ALTER TABLE %I ALTER COLUMN geom TYPE geometry(MultiPolygon, %s) USING ST_Force2D(geom)', plan_tbname, geom_srid);
   		END IF;
		
		-- 判断多规合一各个图层SRID并进行必要的转换
		---- 防止“ERROR:  Geometry SRID (4490) does not match column SRID (4508)”的发生
        EXECUTE 'SELECT DISTINCT ST_SRID(geom) FROM ' || plan_tbname INTO geom_srid;
        IF geom_srid != 4490 THEN
		EXECUTE format('ALTER TABLE %I ALTER COLUMN geom TYPE geometry(MultiPolygon,%s) 
			USING ST_Transform(ST_SetSRID(geom, ST_SRID(geom)) , 4490)', plan_tbname, geom_srid);
		END IF;
		-- 为geom列建立gist索引
		EXECUTE format('CREATE INDEX %s ON %I USING gist (geom)', plan_tbname || '_geom_gix', plan_tbname);
    END LOOP;
END;
$func$
LANGUAGE plpgsql;
select process();
