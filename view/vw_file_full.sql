﻿-- ******************************************************************************
-- Open/view files in qgep
-- ******************************************************************************
--1. ADD fk_data_media : 
-- ******************************************************************************

-- Modification of table od_file --> insert fk_data_media
/*
ALTER TABLE qgep.od_file
ADD COLUMN fk_data_media character varying(16);
-- ******************************************************************************
-- 2. qgep.vw_file : 
-- ******************************************************************************

-- View: qgep.vw_file
DROP VIEW qgep.vw_file;
*/
CREATE OR REPLACE VIEW qgep.vw_file AS 
 SELECT f.obj_id,
    f.identifier,
    f.kind AS file_kind,
    f.object,
    f.class,
    -- dm.path,   
    dm.path::text || f.path_relative::text AS _url,
    f.fk_dataowner as dataowner,
    f.fk_provider as provider,
    f.remark
   FROM qgep.od_file f
     LEFT JOIN qgep.od_data_media dm ON dm.obj_id::text = f.fk_data_media::text;

ALTER TABLE qgep.vw_file
  OWNER TO postgres;

-- ******************************************************************************
-- 3. FUNCTIONS : 
-- ******************************************************************************

-- Function: qgep.vw_file_delete()
-- DROP FUNCTION qgep.vw_file_delete();

CREATE OR REPLACE FUNCTION qgep.vw_file_delete()
  RETURNS trigger AS
$BODY$
	BEGIN
		DELETE FROM qgep.od_file WHERE obj_id = OLD.obj_id;
		RETURN NULL;
	END;
	$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION qgep.vw_file_delete()
  OWNER TO postgres;


-- ******************************************************************************
-- Function: qgep.vw_file_insert()
-- DROP FUNCTION qgep.vw_file_insert();
CREATE OR REPLACE FUNCTION qgep.vw_file_insert()
  RETURNS trigger AS
$BODY$

BEGIN

NEW._url = replace(NEW._url, '\', '/');

INSERT INTO qgep.od_file(
        class,
	identifier,
	kind,
	object,
	path_relative,
	fk_dataowner,
	fk_provider,
	fk_data_media,
	remark)

SELECT
  NEW.class,
  NEW.identifier, 
  NEW.file_kind,
  NEW.object,
  SUBSTRING(NEW._url, LENGTH("path")+1, LENGTH(NEW._url)), -- path_relative,
  NEW.dataowner, -- fk_dataowner,
  NEW.provider, -- fk_provider,
  obj_id, -- fk_data_media
  NEW.remark  
FROM qgep.od_data_media
WHERE "path" = SUBSTRING(NEW._url FROM 1 FOR LENGTH("path"))
ORDER BY LENGTH("path") DESC
LIMIT 1;

-- FOUND is a special variable which is always FALSE at the beginning of a PL/pgsql function and will be set by
-- e.g. INSERT to TRUE if at least one row is affected.
IF NOT FOUND THEN
  RAISE WARNING 'Could not insert. File not in repository set in od_data_media!';
END IF;

  RETURN NEW;
END; $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

ALTER FUNCTION qgep.vw_file_insert()
  OWNER TO postgres;


  -- ******************************************************************************
-- Function: qgep.vw_file_update()
-- DROP FUNCTION qgep.vw_file_update();

CREATE OR REPLACE FUNCTION qgep.vw_file_update()
  RETURNS trigger AS
$BODY$
BEGIN

NEW._url = replace(NEW._url, '\', '/');

  UPDATE  qgep.od_file
    SET 
    class = NEW.class,
    identifier = NEW.identifier,
    kind = NEW.file_kind,
    object = NEW.object,
    path_relative = SUBSTRING(NEW._url, LENGTH(dm.path)+1, LENGTH(NEW._url)), 
    fk_dataowner = NEW.dataowner,
    fk_provider = NEW.provider,
    fk_data_media = dm.id, 
    remark = NEW.remark

FROM (
  SELECT obj_id as id,
	path
	FROM qgep.od_data_media
	WHERE path = SUBSTRING(NEW._url FROM 1 FOR LENGTH(path))
	ORDER BY LENGTH(path) DESC
	LIMIT 1)  dm

WHERE obj_id = OLD.obj_id;

     
  RETURN NEW;
END; 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION qgep.vw_file_update()
  OWNER TO postgres;


-- TRIGGERS :
-- ******************************************************************************
-- Trigger: vw_file_delete on qgep.vw_file
-- DROP TRIGGER vw_file_delete ON qgep.vw_file;

CREATE TRIGGER vw_file_delete
  INSTEAD OF DELETE
  ON qgep.vw_file
  FOR EACH ROW
  EXECUTE PROCEDURE qgep.vw_file_delete();

-- Trigger: vw_file_insert on qgep.vw_file
-- DROP TRIGGER vw_file_insert ON qgep.vw_file;

CREATE TRIGGER vw_file_insert
  INSTEAD OF INSERT
  ON qgep.vw_file
  FOR EACH ROW
  EXECUTE PROCEDURE qgep.vw_file_insert();

-- Trigger: vw_file_update on qgep.vw_file
-- DROP TRIGGER vw_file_update ON qgep.vw_file;

CREATE TRIGGER vw_file_update
  INSTEAD OF UPDATE
  ON qgep.vw_file
  FOR EACH ROW
  EXECUTE PROCEDURE qgep.vw_file_update();
-- ******************************************************************************
