-- deyu tian
CREATE or replace FUNCTION process(_tb1 regclass, town_name TEXT, town_id TEXT) 
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
    EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS sxm VARCHAR DEFAULT ''%s''', _tb1, city_name);
    EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS sxdm VARCHAR DEFAULT ''%s''', _tb1, city_code);
    EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS xzqhdm VARCHAR DEFAULT ''%s''', _tb1, town_id);
    EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS xzmc VARCHAR DEFAULT ''%s''', _tb1, town_name);

    -- 对违法图层进行SRID检测和赋值
    EXECUTE format('ALTER TABLE %s ALTER COLUMN geom TYPE geometry(MultiPolygon,4490) 
				   USING ST_Transform(ST_SetSRID(geom, ST_SRID(geom)) , 4490)', _tb1);
	FOR plan_tbname IN
      SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE'
      AND table_name LIKE 'plan%'
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
		
		-- 空间关系判断
		---- 为违法图层定义规划图层对应字段
		EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS %s VARCHAR', _tb1, 'sf' || right(plan_tbname, 6));
		---- 判断空间关系并为新字段赋值
		------  完全包含在内，即contains
		EXECUTE format('UPDATE %s 
					   SET %s = ''%s'' 
					   WHERE %s.gid 
					   IN (SELECT %s.gid FROM %I, %s WHERE ST_Contains(%I.geom, %s.geom))', 
					   _tb1, 'sf' || right(plan_tbname, 6), '在' || right(plan_tbname, 6) || '内', _tb1, 
					   _tb1, plan_tbname, _tb1, plan_tbname, _tb1);
		------ OVERLAP但是90%以上在内部
		EXECUTE format('UPDATE %s 
					   SET %s = ''%s'' 
					   WHERE %s.gid 
					   IN (SELECT %s.gid FROM %I, %s WHERE ST_Overlaps(%I.geom, %s.geom)
					   AND (ST_Area(ST_Intersection(%I.geom, %s.geom)) / ST_Area(%s.geom) >= 0.9))', 
					   _tb1, 'sf' || right(plan_tbname, 6), '在' || right(plan_tbname, 6) || '内', _tb1, 
					   _tb1, plan_tbname, _tb1, plan_tbname, _tb1,
					   plan_tbname, _tb1, _tb1);
		------ OVERLAP但是90%以上在外部
		EXECUTE format('UPDATE %s 
					   SET %s = ''%s'' 
					   WHERE %s.gid 
					   IN (SELECT %s.gid FROM %I, %s WHERE ST_Overlaps(%I.geom, %s.geom)
					   AND ((ST_Area(%s.geom) - ST_Area(ST_Intersection(%I.geom, %s.geom))) / ST_Area(%s.geom) >= 0.9))', 
					   _tb1, 'sf' || right(plan_tbname, 6), '在' || right(plan_tbname, 6) || '外', _tb1, 
					   _tb1, plan_tbname, _tb1, plan_tbname, _tb1,
					   _tb1, plan_tbname, _tb1, _tb1);
		------ OVERLAP的其他情况，同时在内外
		EXECUTE format('UPDATE %s 
					   SET %s = ''%s'' 
					   WHERE %s.gid 
					   IN (SELECT %s.gid FROM %I, %s WHERE ST_Overlaps(%I.geom, %s.geom)
					   AND (ST_Area(ST_Intersection(%I.geom, %s.geom)) / ST_Area(%s.geom) < 0.9)
					   AND ((ST_Area(%s.geom) - ST_Area(ST_Intersection(%I.geom, %s.geom))) / ST_Area(%s.geom) < 0.9))', 
					   _tb1, 'sf' || right(plan_tbname, 6), '同时在' || right(plan_tbname, 6) || '内外', _tb1, 
					   _tb1, plan_tbname, _tb1, plan_tbname, _tb1,
					   plan_tbname, _tb1, _tb1,
					   _tb1, plan_tbname, _tb1, _tb1);
		EXIT;
    END LOOP;
END;
$func$
LANGUAGE plpgsql;
select process('data_prod_feb.caikuang_2019_01_02_penglai', '蓬莱镇', '469005000');
