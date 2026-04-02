/*
=============================================================================
Script    : adm_001_storage_monitor_storage_growth.sql
Categoría : Administration - Storage
Autor     : Jaime Sanchez
Programa  : Oracle ACE Apprentice
Versión   : 1.0
Fecha     : 2026-03-30
=============================================================================
Descripción:
    Script para saber el crecimiento de almacenamiento en la base de datos Oracle

Prerrequisitos:
    - Oracle Database 11g o superior
    - Privilegios: dba_segments y dba_users;

Parámetros:

Uso:
Para cargar data de storage
execute EDBATOOLS.pkg_mante_dba.carga;
Para visualizar crecimiento:
variable rc refcursor;
exec EDBATOOLS.pkg_crecimiento.repo_diario(sysdate-1,sysdate,'X',:rc);
print rc;

Ejemplo de salida- Reporte por Objeto
    OWNER     SEGMENT_NAME    SEGMENT_TYPE    CRECI_GB    FINAL   INICIAL    %
    --------- ------------    ------------    -------    --------  -------- -----
    EDBATOOLS TABLA1           TABLE             2.5        4.5     2.0       125%

Historial de cambios:
    1.0 | 2026-03-30 | Jaime Sanchez | 1.0
=============================================================================
*/
--1. Creamos el schema edbatools
create tablespace EDBATOOLS_MDT;
create user edbatools identified by password;
--Brindamos accesos a la dba_segments
grant select on dba_segments to edbatools;
grant select on dba_users to edbatools;
--Brindamos privilegios sobre el tablespace
alter user edbatools quota unlimited on EDBATOOLS_MDT;
--Creamos secuencia
CREATE SEQUENCE EDBATOOLS.S_SEGMENTO
  START WITH 62469
  MAXVALUE 999999999999999999999999999
  MINVALUE 1
  NOCYCLE
  CACHE 20
  NOORDER;

---Creamos las tablas necesarias para el analisis de crecimiento
CREATE TABLE EDBATOOLS.DSEGMENTOS
(
  ID               NUMBER,
  FECHA            DATE,
  TIPO             VARCHAR2(1),
  OWNER            VARCHAR2(30),
  SEGMENT_NAME     VARCHAR2(100),
  PARTITION_NAME   VARCHAR2(64),
  SEGMENT_TYPE     VARCHAR2(18),
  TABLESPACE_NAME  VARCHAR2(40),
  MB               NUMBER,
  EXTENTS          NUMBER
)
TABLESPACE EDBATOOLS_MDT;

---Creamos el store procedure para el analisis
CREATE OR REPLACE PACKAGE EDBATOOLS.pkg_crecimiento
is
  procedure repo_diario(pfechai date,pfechaf date,ptipo varchar2,presultado OUT SYS_REFCURSOR );
end;
/

CREATE OR REPLACE PACKAGE BODY EDBATOOLS.pkg_crecimiento
is
PROCEDURE repo_diario(pfechai date,pfechaf date,ptipo varchar2,presultado OUT SYS_REFCURSOR ) AS 
vidi number;
vidf number;
vfi date;
vff date;
BEGIN 

--Obtenemos los Ids de los dias a comparar
--Inicio
select ID,fecha
into vidi,vfi
from EDBATOOLS.dsegmentos
where fecha>=pfechai
and fecha<pfechai+1
and rownum=1;

--Fin
select ID,fecha
into vidf,vff
from EDBATOOLS.dsegmentos
where fecha>=pfechaf
and fecha<pfechaf+1
and rownum=1;

dbms_output.put_line('idi->'||vidi||' idf->'||vidf);
IF ptipo='G' THEN
--Reporte General
OPEN presultado FOR
select round((sum(b.mb-a.mb))/1024,2) creciGB
from
(
select  *
from EDBATOOLS.dsegmentos
where id=vidi  ) a,
(
select *
from EDBATOOLS.dsegmentos
where id=vidf ) b 
where a.owner=b.owner
and a.segment_name=b.segment_name
and a.segment_type not in ('TYPE2 UNDO')
and nvl(a.partition_name,'R')=nvl(B.partition_name,'R')
and b.mb-a.mb>0; -- excluimos los borrados
--group by a.owner
--order by 2 desc;

ELSIF ptipo='E' THEN
--Reporte Esquema
OPEN presultado FOR
select a.owner,round((sum(b.mb-a.mb))/1024,2) creciGB
from
(
select  *
from EDBATOOLS.dsegmentos
where id=vidi  ) a,
(
select *
from EDBATOOLS.dsegmentos
where id=vidf ) b 
where a.owner=b.owner
and a.segment_name=b.segment_name
and a.segment_type not in ('TYPE2 UNDO')
and nvl(a.partition_name,'R')=nvl(B.partition_name,'R')
and b.mb-a.mb>0 -- excluimos los borrados
group by a.owner
order by 2 desc;

ELSIF ptipo='V' THEN
--Reporte General
OPEN presultado FOR
select round((sum(b.mb-a.mb))/1024,2) creciGB
from
(
select  *
from EDBATOOLS.dsegmentos
where id=vidi  ) a,
(
select *
from EDBATOOLS.dsegmentos
where id=vidf ) b 
where a.owner=b.owner
and a.segment_name like 'VTEX%'
and a.segment_name=b.segment_name
and a.segment_type not in ('TYPE2 UNDO')
and nvl(a.partition_name,'R')=nvl(B.partition_name,'R')
and b.mb-a.mb>0; -- excluimos los borrados
--group by a.owner
--order by 2 desc;
ELSE

--Reporte de Objetos
OPEN presultado FOR
select a.owner,a.segment_name,a.partition_name,a.segment_type,round((b.mb-a.mb)/1024,2) creciGB,b.mb final,a.mb inicial,round((b.mb-a.mb)/b.mb*100,2) "%"
from
(
select  *
from EDBATOOLS.dsegmentos
where id=vidi  ) a, 
(
select *
from EDBATOOLS.dsegmentos
where id=vidf ) b
where a.owner=b.owner
and a.segment_name=b.segment_name
and a.segment_type not in ('TYPE2 UNDO')
and nvl(a.partition_name,'R')=nvl(B.partition_name,'R')
and b.mb-a.mb>100
order by 5 desc;

END IF;
END repo_diario;
END;
/

--Creamos store que recolecta la informacion
CREATE OR REPLACE PACKAGE EDBATOOLS.pkg_mante_dba
is
  procedure data_segmentos(ptipo varchar2);
  procedure carga;
end;
/

CREATE OR REPLACE PACKAGE BODY EDBATOOLS.pkg_mante_dba
is

procedure data_segmentos(ptipo varchar2) as
  VID NUMBER;
begin
  select S_SEGMENTO.NEXTVAL INTO vid from dual;


  INSERT INTO edbatools.DSEGMENTOS(ID,FECHA,TIPO,OWNER,SEGMENT_NAME,PARTITION_NAME,SEGMENT_TYPE,
  TABLESPACE_NAME,MB,EXTENTS)
  select VID,SYSDATE,PTIPO,OWNER,SEGMENT_NAME,PARTITION_NAME,SEGMENT_TYPE,TABLESPACE_NAME,BYTES/1024/1024,EXTENTS
  from dba_segments
  where owner not in (select username from dba_users where oracle_maintained='YES');
  commit;
end;

procedure carga as
begin
PKG_MANTE_DBA.DATA_SEGMENTOS('B');
end;
end;
/


--Crear Job de recoleccion de informacion de almacenamiento
BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'EDBATOOLS.CARGA_USO_STORAGE'
      ,start_date      => TO_TIMESTAMP_TZ('2026/03/30 14:00:00.000000 -05:00','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY;BYHOUR=23; BYMINUTE=0; BYSECOND=0;'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'EDBATOOLS.pkg_mante_dba.carga'
      ,comments        => NULL
    );
END;
/

