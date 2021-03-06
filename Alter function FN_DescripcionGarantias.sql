USE [Topaz_siboif]
GO
/****** Object:  UserDefinedFunction [dbo].[FN_DescripcionGarantias]    Script Date: 31/10/2018 09:21:33 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[FN_DescripcionGarantias]
(
	-- Add the parameters for the function here
	@NumCredito AS NUMERIC(15,0)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar AS NVARCHAR(MAX)

	SELECT @ResultVar = STUFF(( SELECT  ' - ' + Detalle.DescGarantia
	   FROM (SELECT REPLACE( REPLACE( REPLACE(REPLACE(replace(replace(gg.DESCRIPCION ,CHAR(9),''),'-','_') ,Char(10),' '),Char(13), ''),'Ñ','N'),'"','''' )  AS DescGarantia
			 FROM  GR_GARANTIAS gg with (nolock)
			   INNER JOIN GR_RELACIONGTIACREDSOLIC gr ON gr.NROGARANTIA = gg.NROGARANTIA AND gr.TZ_LOCK = 0
			   INNER JOIN SALDOS s ON gr.NROSOLICITUD = s.C1704 AND s.TZ_LOCK = 0			
	         WHERE s.CUENTA = @NumCredito
			   AND gg.TZ_LOCK = 0
			 GROUP BY gg.DESCRIPCION) Detalle
			 FOR XML PATH('')), 1, 2, '')

	-- Return the result of the function
	IF (@ResultVar is NULL)
	BEGIN
		SET @ResultVar = ''
	END
	
	RETURN @ResultVar
END

