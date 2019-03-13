-- deyu tian
CREATE or replace FUNCTION process(_tb1 regclass, town_name TEXT, town_id TEXT) 
RETURNS VOID AS
$func$
DECLARE
   city_name text := '文昌市';  -- assign at declaration
   city_code text := '469005';
   plan_tbname text;
   plan_srid integer;
BEGIN
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN sxm VARCHAR DEFAULT ' || city_name;
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN sxdm VARCHAR DEFAULT ' || city_code;
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN xzqhdm VARCHAR DEFAULT ' || town_id;
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ADD COLUMN xzmc VARCHAR DEFAULT ' || town_name;

    -- 对违法图层进行SRID检测和赋值
    EXECUTE 'ALTER TABLE ' || _tb1 || ' ALTER COLUMN geom TYPE geometry(MultiPolygon,4490) 
    USING ST_Transform(ST_SetSRID(geom, SELECT ST_SRID(geom) FROM ' || _tb1 || ' ) , 4490);'
    FOR plan_tbname IN
      SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE'
      AND table_name LIKE 'plan%'
    LOOP
        -- 判断多规合一各个图层SRID并进行必要的转换
        EXECUTE 'SELECT ST_SRID(geom) FROM ' || plan_tbname INTO plan_srid;
        IF plan_srid != 4490 THEN
          EXECUTE 'ALTER TABLE ' || plan_tbname || ' ALTER COLUMN geom TYPE geometry(MultiPolygon,4490) 
            USING ST_Transform(ST_SetSRID(geom, SELECT ST_SRID(geom) FROM ' || plan_tbname || ' ) , 4490);'
        END IF;
        -- 空间关系判断在这里实现
        -- EXECUTE 'ALTER ' 
        IF NOT ST_Intersects(_tb1.geom, plan_tbname.geom) THEN
          RAISE notice '不重叠！';
        ELSE
          NULL;
          -- IF THEN
          --   NULL;
          -- ELSIF THEN
          --   NULL;
          -- ELSE
          --   --
          -- END IF;
        END IF;
        -- EXECUTE format('CREATE TABLE %I AS TABLE %I', tablename || '_backup', tablename);
    END LOOP;
END;
$func$
LANGUAGE plpgsql;
select process('data_prod_feb.caikuang_2019_01_02_penglai', '保罗镇', '469005000');
