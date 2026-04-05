/*
=============================================================================
Script    : adm_002_security_controlar_accesos.sql
Categoría : Administration - Security
Autor     : Jaime Sanchez
Programa  : Oracle ACE Apprentice
Versión   : 1.0
Fecha     : 2026-04-04
=============================================================================
Descripción:
    Script para controla el acceso a la base de datos Oracle, est control se dara mediare ip, usuarios, pc y pogramas.

Prerrequisitos:
    - Oracle Database 11g o superior
    - Privilegios: Select a v_$session

Parámetros:
No hay parametros
Uso:
Poner el package en trigger after logon como se indica en el paso 3.

Ejemplo de salida - Si el usuario no esta autorizado
'Infraccion de Acceso - No esta autorizado'

Historial de cambios:
    1.0 | 2026-04-04 | Jaime Sanchez | Creación
=============================================================================
*/
--Si aún no tienes el esquema edbatools ir al script adm_001_storage*

--0. Brindamos privilegios de select
grant select on sys.v_$session to edbatools;

-- 1. Creamos las tablas necesarias

--Tabla para activar o desactivar la validacion de accesos
--id=1,idopcion=1, valor=1 activo, valor=0 desactivado 
CREATE TABLE EDBATOOLS.MAE_CONFIGURACION
(
  ID           NUMBER,
  IDOPCION     NUMBER,
  VALOR        NUMBER,
  DESCRIPCION  VARCHAR2(60)
)
TABLESPACE EDBATOOLS_MDT;

--Registra todos los logueos a la bd que pasan por el trigger
CREATE TABLE EDBATOOLS.LOG_ACCESOS
(
  FECHA     DATE,
  SID       NUMBER,
  SERIAL#   NUMBER,
  USERNAME  VARCHAR2(30),
  OSUSER    VARCHAR2(30),
  EQUIPO    VARCHAR2(100),
  IP        VARCHAR2(20),
  PROGRAMA  VARCHAR2(48),
  MODULE    VARCHAR2(256),
  TERMINAL  VARCHAR2(256),
  TIPO      INTEGER
)
TABLESPACE EDBATOOLS_MDT;

--Lista blanca de equipo que tendran accesos
CREATE TABLE EDBATOOLS.MAE_EQUIPOS
(
  EQUIPO  VARCHAR2(40),
  LISTA   VARCHAR2(1),
  ESTADO  NUMBER
)
TABLESPACE EDBATOOLS_MDT;

--Lista blanca de programas que tendran accesos
CREATE TABLE EDBATOOLS.MAE_MODULOS
(
  MODULO  VARCHAR2(100),
  LISTA   VARCHAR2(1),
  ESTADO  NUMBER
)
TABLESPACE EDBATOOLS_MDT;


--2. Creamos el package
--En esta primera version tanto la vaidacion de ip como de usuarios aun esta dentro del codigo, en una posterior version se pondra en tablas.
CREATE OR REPLACE package EDBATOOLS.pkg_acceso_bd
is 
procedure acceso;
function fconfiguracion(pid integer,pidopcion integer) return integer;
procedure registra(psid number,pserial number,pusername varchar2,posuser varchar2,pequipo varchar2,pip varchar2,pprograma varchar2,pmodule varchar2,pterminal varchar2,ptipo integer);
procedure valida;
function fvalidapc(pequipo varchar2) return integer;
function fvalidamodule(pmodule varchar2) return integer;
function fvalidausuario(pusername varchar2,pequipo varchar2,pmodule varchar2) return integer ;
function fvalidaip (pip varchar2) return integer;
end;
/

CREATE OR REPLACE package body EDBATOOLS.pkg_acceso_bd
is 
procedure acceso is
--Valida si esta activo la validacion de acceso
vconfiguracion integer;
begin
vconfiguracion:=fconfiguracion(1,1);
  if vconfiguracion=1 then
    valida;
  end if;   
end;
function fconfiguracion(pid integer,pidopcion integer) return integer is
--Obtiene si el servicio esta activo o no--
vflag integer;

begin
 select valor into vflag
 from mae_configuracion
 where id=pid
 and idopcion=pidopcion;
 return vflag;
exception when others then
 return 0; 
end;
procedure registra(psid number,pserial number,pusername varchar2,posuser varchar2,pequipo varchar2,pip varchar2,pprograma varchar2,pmodule varchar2,pterminal varchar2,ptipo integer)
is
begin
  insert into log_accesos(FECHA, SID, SERIAL#, USERNAME, OSUSER, EQUIPO, IP, PROGRAMA, MODULE, TERMINAL, TIPO)
  values(sysdate,psid,pserial,pusername,posuser,pequipo,pip,pprograma,pmodule,pterminal,ptipo);
  commit;
end;
procedure valida is
vusername sys.v_$session.username%TYPE;
vprograma sys.v_$session.program%TYPE;
vmodule  sys.v_$session.module%TYPE;
vterminal sys.v_$session.terminal%TYPE;
vmachine sys.v_$session.machine%TYPE;
vosuser sys.v_$session.osuser%TYPE;
vsid sys.v_$session.sid%TYPE;
vserial sys.v_$session.serial#%TYPE;
vaction sys.v_$session.action%TYPE;
vvalidapc integer;
vvalidamodule integer;
vvalidauser integer;
vvalidaip integer;
vip varchar2(60);
begin

SELECT username,program,module,terminal,machine,osuser,sid,serial#,action
INTO vusername,vprograma,vmodule,vterminal, vmachine,vosuser,vsid,vserial,vaction
FROM sys.v_$session
WHERE audsid = USERENV('SESSIONID')
AND audsid != 0 -- No chequea conexiones SYS
AND rownum = 1;


 --obtenemos la IP
     select SYS_CONTEXT('USERENV', 'IP_ADDRESS', 15) INTO vip from dual;
       vvalidaip:=fvalidaip(vip);
       if vvalidaip=0 then
        registra(vsid,vserial,vusername,vosuser,vmachine,null,vprograma,vmodule,vterminal,0);
        raise_application_error(-20100,'Infraccion de Acceso - No esta autorizado');
       END IF; 

--Validamos si el equipo esta permitido
vvalidapc:=fvalidapc(upper(vmachine));
if vvalidapc=0 then
 --Validamos si el programa esta permitido
  
 if vaction like 'Primary%' then --Por ahora acction dummy
        registra(vsid,vserial,vusername,vosuser,vmachine,null,vprograma,vmodule,vterminal,2);
        raise_application_error(-20100,'Infraccion de Acceso - No esta autorizado');
 END IF;
 
 
  vvalidamodule:=fvalidamodule(upper(vmodule));
  if vvalidamodule=0 then
    vvalidauser:=fvalidausuario(upper(vusername), upper(vmachine), upper(vmodule));
    if vvalidauser=0 then
       --obtenemos la IP
      -- select SYS_CONTEXT('USERENV', 'IP_ADDRESS', 15) INTO vip from dual;
      -- vvalidaip:=fvalidaip(vip);
      -- if vvalidaip=0 then
        registra(vsid,vserial,vusername,vosuser,vmachine,null,vprograma,vmodule,vterminal,0);
        raise_application_error(-20100,'Infraccion de Acceso - No esta autorizado');
      -- else
       -- registra(vsid,vserial,vusername,vosuser,vmachine,null,vprograma,vmodule,vterminal,1);  
       --end if; 
    else
        registra(vsid,vserial,vusername,vosuser,vmachine,null,vprograma,vmodule,vterminal,1);
    end if;    
  else
    registra(vsid,vserial,vusername,vosuser,vmachine,null,vprograma,vmodule,vterminal,1);
  end if;
else  
  registra(vsid,vserial,vusername,vosuser,vmachine,null,vprograma,vmodule,vterminal,1);
end if; 

end;
function fvalidapc(pequipo varchar2) return integer is
vflag integer;
begin
vflag:=0;
 select 1
 into vflag
 from mae_equipos
 where equipo =pequipo
 and estado=1;
 return vflag;
exception when no_data_found then
 return vflag; 
end;
function fvalidamodule(pmodule varchar2) return integer is
vflag integer;
begin
 vflag:=0;
 select 1
 into vflag
 from mae_modulos
 where pmodule = upper(modulo)
 and estado=1 ;
 return vflag;
exception 
when no_data_found then
 return vflag;
when too_many_rows THEN
 vflag:=1;
 return vflag;
end;
function fvalidausuario(pusername varchar2,pequipo varchar2,pmodule varchar2) return integer is
vflag integer;
begin
  vflag:=0;
  IF pusername='USER1' or pusername='USER2' or pusername='USER3' THEN --aqui reemplazamos por los usuarios permitidos
     vflag:=1;
  END IF;   
     
  return vflag;
end;
function fvalidaip (pip varchar2) return integer is
vflag integer;
begin
  vflag:=1;
  IF pip='10.20.12.16' THEN --Ip Dummy , aca se ponen las ips de la lista negra.
     vflag:=0;
  END IF;   
  return vflag;
end;    
end;
/

--3. Se agrega a un trigger after logon para controlar los accesos.
CREATE OR REPLACE TRIGGER SYS.VALIDA_ACCESO
AFTER LOGON ON DATABASE
BEGIN
 edbatools.pkg_acceso_bd.acceso;
END;
/

