DROP VIEW IF EXISTS  qgep.vw_file; 
CREATE OR REPLACE VIEW qgep.vw_file AS
SELECT  f.obj_id,
	f.identifier,
	f.kind AS file_kind,
	f.object,
	f.path_relative,
	dm.kind as data_media_kind,
	dm.path,
	dm.path || '/'||f.identifier as _url,
	f.remark
FROM qgep.od_file f
LEFT JOIN qgep.od_data_media dm ON dm.obj_id = f.fk_data_media;
	
	
