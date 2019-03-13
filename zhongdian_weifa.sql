SELECT COUNT(ct.name) as count, ct.name
FROM wenchang_xiangzhen_bound AS ct
JOIN
(
  SELECT st.the_geom
  FROM weijian_union_2017_2018 AS st
  JOIN jiben_nongtian as fo
  ON ST_Contains(fo.geom, st.the_geom)
) as st_in_fo
ON st_intersects(ct.the_geom, st_in_fo.the_geom)
GROUP BY ct.name
;
