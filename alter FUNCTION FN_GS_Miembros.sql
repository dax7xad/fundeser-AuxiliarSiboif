USE [Topaz_siboif]
GO

/****** Object:  UserDefinedFunction [dbo].[FN_GS_Miembros]    Script Date: 31/10/2018 02:01:33 p.m. ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


alter FUNCTION [dbo].[FN_GS_Miembros](@FECHASALDO  SMALLDATETIME)
RETURNS @TABLA_RESULTADO TABLE (
 		 NRO_PRESTAMO numeric(15,0)
 		,SALDO_JTS_OID NUMERIC(10,0)
 		,INTEGRANTES_PORC  FLOAT
 		,NOM_MIEMBRO  NVARCHAR(MAX)
 		,COD_CLIENTE_M NUMERIC(12,0)
 		,FECHA_SALDO DATETIME
)
AS
BEGIN

DECLARE @Estados AS TABLE (
							codigoEstado CHAR(1)	
							)
-- Listado de los estados del credito a filtrar
		INSERT INTO @Estados
		SELECT 'V'
		UNION 
		SELECT 'E'
		UNION
		SELECT 'N'
		UNION              /* se incorpora este filtro para no afectar los reportes historicos*/
		SELECT 'C'
		--SELECT  CASE WHEN @FECHASALDO>'31/05/2016' THEN '' ELSE 'C' END
		
INSERT INTO @TABLA_RESULTADO
SELECT POR_MIEMBROS.NRO_PRESTAMO, POR_MIEMBROS.JTS_OID,
        POR_MIEMBROS.INTEGRANTES_PORC, POR_MIEMBROS.NOM_MIEMBRO,
        POR_MIEMBROS.COD_CLIENTE_M, POR_MIEMBROS.FECHA_SALDO
 FROM
 (	 -- DETALLE DEL REPORTE
	-- Detalle de distribución de los porcentaje "CREDITOS TOPAZ"
	SELECT S.NRO_PRESTAMO,S.JTS_OID , (SS2.C5092 / s.IMPORTE_DESEMBOLSO_MO) AS 'INTEGRANTES_PORC'
	,cc.C1000 AS 'NOM_MIEMBRO',cc.C0902 AS COD_CLIENTE_M,S.FECHA_SALDO
	FROM 
	(
	SELECT UNIVERSO.NRO_PRESTAMO,UNIVERSO.JTS_OID,UNIVERSO.IMPORTE_DESEMBOLSO_MO,UNIVERSO.FECHA_SALDO
	  FROM
	(
	SELECT * FROM dbo.FN_EGP_FUNDESER_UNIVERSO(@FECHASALDO) --FN_EG_UNIVERSO(@FECHASALDO) 
	WHERE TIPO_PRESTAMO !='INDIVIDUAL'	AND CODIGO_ESTADO   IN ( SELECT codigoEstado FROM @Estados)
  	)UNIVERSO
	)S
	--
	INNER JOIN SL_SOLICITUDCREDITO ss  ON SS.C5002 =s.NRO_PRESTAMO
	INNER JOIN ( --RELACION CON LOS SOLICITUDES Y PARA OBTENER PORCENTAJE DE SALDOS Y EL MONTO POR MIEMBROS
	SELECT SS.C5080, SS.C5082 
	,'C5092' = CASE WHEN SS.C5092>0 THEN  SS.C5092  ELSE SS.C5088 END
	FROM SL_SOLICITUDCREDITOPERSONA SS	WITH (NOLOCK)						
	WHERE SS.TZ_LOCK=0 AND ss.C5084 =802 AND SS.TIPOSOLICITUD='A' AND SS.C5088>0
	) ss2  ON SS.C5000=SS2.C5080  
	INNER JOIN CL_RELPERDOC AS cr WITH (NOLOCK) ON CR.IDPERSONA =SS2.C5082 AND cr.TIPODOC IN ('C','E') AND cr.ESTADO = 'A' AND cr.PRINCIPAL = 'S' 	
	INNER JOIN CL_CLIENTES cc WITH (NOLOCK) ON CC.C0902 =CR.IDPERSONA
UNION ALL
/* + ABACUS + + ABACUS ++ ABACUS ++ ABACUS ++ ABACUS ++ ABACUS ++ ABACUS ++ ABACUS ++ ABACUS + */
-- PARTE DE LOS CREDITOS EN ABACUS
	 SELECT S.NRO_PRESTAMO, S.JTS_OID, mgp.Pc AS 'INTEGRANTES_PORC'
	 ,CEDULA_MIEMBROS.NOM_CLIENTE,CEDULA_MIEMBROS.COD_CLIENTE_M,S.FECHA_SALDO
	 FROM
	 (
	SELECT UNIVERSO.NRO_PRESTAMO,UNIVERSO.JTS_OID,UNIVERSO.CODIGO_CLIENTE ,UNIVERSO.IMPORTE_DESEMBOLSO_MO
	,universo.FECHA_SALDO  
	  FROM
	(
	SELECT * FROM dbo.FN_EGP_FUNDESER_UNIVERSO(@FECHASALDO)--FN_EG_UNIVERSO(@FECHASALDO)
	)UNIVERSO 
	WHERE TIPO_PRESTAMO !='INDIVIDUAL' AND CODIGO_ESTADO IN ( SELECT codigoEstado FROM @Estados)
	
	--GROUP BY UNIVERSO.NRO_PRESTAMO,UNIVERSO.SALDO_JTS_OID,UNIVERSO.CODIGO_CLIENTE
	)S
	INNER JOIN	
	( -- PARTE QUE OBTIENE LA CEDULA DE CADA MIEMBRO DE LOS GRUPOS SOLIDARIO
	SELECT clp.C1430  AS 'CODIGO_CLIENTE', clp.C1433 ,clp.C1437, clp.IDPERSONA 
	,cr.NRODOCUMENTO COLLATE SQL_AltDiction_CP850_CI_AI AS NRODOCUMENTO 
	,CC.C1000 AS 'NOM_CLIENTE',CC.C0902 AS 'COD_CLIENTE_M'
	FROM CL_CLIENTPERSONA clp WITH (NOLOCK)
	INNER JOIN CL_RELPERDOC AS cr WITH (NOLOCK) ON CR.IDPERSONA =clp.IDPERSONA AND cr.TIPODOC = 'C' AND cr.ESTADO = 'A' AND cr.PRINCIPAL = 'S'
	INNER JOIN CL_CLIENTES cc WITH (NOLOCK) ON CC.C0902 =clp.IDPERSONA
	--WHERE clp.C1430=  6745776
	)CEDULA_MIEMBROS ON  CEDULA_MIEMBROS.CODIGO_CLIENTE = S.CODIGO_CLIENTE
	INNER JOIN MiembrosGrupalesPorcion AS mgp WITH (NOLOCK) ON MGP.ID = CONVERT( NVARCHAR(MAX),CEDULA_MIEMBROS.NRODOCUMENTO)+ CONVERT(NVARCHAR(MAX),S.NRO_PRESTAMO)
	)POR_MIEMBROS
   RETURN;
END;

GO


