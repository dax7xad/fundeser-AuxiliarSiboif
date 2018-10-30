
/*
*  Autor: Alvaro Dax Diaz Amaya
*  Fecha de creacion: 05-09-2018
*  Descripcion breve: Auxiliar de Cartera solicitado por la SIBOIF
*  Version: 1.0.1
* */

-- Cuerpo de la funcion
DECLARE @FechaCorte AS SMALLDATETIME
DECLARE @TC AS NUMERIC(8,4)
DECLARE @ControlVersion AS NVARCHAR(25)
SET @FechaCorte = (SELECT p.FECHAPROCESO  FROM PARAMETROS p)
SELECT @TC = DBO.FN_ObtenerTipoCambio(@FechaCorte)
SET @ControlVersion = (SELECT Id_MaestroUnico FROM Aux_cartera_SIBOIF_Maestro WHERE Estado = 1)
--DROP TABLE #GASTOS_POR_CUOTA_ORIGINAL
SELECT SUM(gpco.Importe_Gastos) AS Importe_Gastos,gpco.Saldos_JTS_OID
INTO #GASTOS_POR_CUOTA_ORIGINAL
FROM GASTOS_POR_CUOTA_ORIGINAL gpco WITH (NOLOCK)
WHERE gpco.Numero_Cuota = 1 
GROUP BY gpco.Saldos_JTS_OID
CREATE INDEX IdxJTS ON #GASTOS_POR_CUOTA_ORIGINAL(Saldos_JTS_OID)

--DROP TABLE #FN_GS_Miembros
SELECT *
INTO #FN_GS_Miembros
FROM dbo.FN_GS_Miembros(@FechaCorte)
CREATE INDEX IdxJTS ON #FN_GS_Miembros(SALDO_JTS_OID)
CREATE INDEX IdxCLIENTE ON #FN_GS_Miembros(COD_CLIENTE_M)


--DROP TABLE #TempEGP
SELECT * 
INTO #TempEGP
FROM dbo.FN_EGP_FUNDESER_UNIVERSO(@FechaCorte) AS egp
WHERE egp.SITUACION_PRESTAMO <> 'Saneado'
CREATE INDEX IdxJTS ON #TempEGP(JTS_OID)
CREATE INDEX IdxCliente ON #TempEGP(CODIGO_CLIENTE)

TRUNCATE TABLE [Aux_cartera_SIBOIF_Resultado_20171130_1-0-0]
INSERT INTO [Aux_cartera_SIBOIF_Resultado_20171130_1-0-0]
(
	Cod_Cliente,
	Nombre_Cliente,
	Num_Identificacion,
	Tipo_persona,
	No_Creditos,
	Deuda_total,
	Cod_Credito,
	Tipo_Credito,
	Tipo_Producto,
	Sector,
	Fuente_Fin,
	Codigo_MUC,
	Monto_Original,
	Moneda,
	Saldo_principal,
	Saldo_interes,
	Monto_Ult_Pago_Ppal,
	Monto_Ult_Pago_Int,
	Fecha_Aprobacion,
	Fecha_Desembolso,
	Fecha_Vencimiento,
	Plazo,
	Fecha_primer_pago,
	Fecha_ultimo_pago_ppal,
	Fecha_ultimo_pago_int,
	Fecha_ingreso_mora_ppal,
	Fecha_ingreso_mora_int,
	Frecuencia_pago_ppal,
	Frecuencia_pago_int,
	Cuotas_programadas,
	Cuotas_pagadas,
	Cuotas_vencidas,
	Modalidad,
	Dias_gracia,
	Tipo_tasa,
	Tasa_contractual,
	Tasa_vigente,
	Tasa_efectiva_vigente,
	Tasa_mora,
	Tipo_garantia,
	Descripcion_garantia,
	Valor_garantia,
	Monto_cuota,
	Cuota_total,
	Principal_corriente,
	Principal_vencido,
	Interes_Cte_Vgte,
	Interes_Cte_Vcdo,
	Interes_moratorio,
	Fecha_prox_pago_ppal,
	Fecha_prox_pago_int,
	Dias_mora_principal,
	Dias_mora_intereses,
	Clasificacion,
	Clasificacion_Cliente,
	Provision,
	Sucursal,
	ASESOR_CREDITO,
	Interno_FechaCorte,
	Interno_ControlVersion
)
SELECT TOP 100
		/*1*/ 'COD_CLIENTE'	= egp.CODIGO_CLIENTE
		/*2*/,'NOMBRE_CLIENTE'= egp.NOMBRE_CLIENTE
		/*3*/,'NUM_IDENTIFICACION' = CASE WHEN egp.TIPO_PRESTAMO = 'GRUPO SOLIDARIO' THEN CoordGrupo.NumDocumento
										   WHEN egp.TIPO_PERSONA = 'J' THEN egp.NUMERO_RUC
										   ELSE egp.NUMERO_DOCUMENTO 
									  END
		/*4*/,'TIPO_PERSONA'	= CASE	WHEN egp.TIPO_PRESTAMO = 'GRUPO SOLIDARIO' THEN CoordGrupo.TIPO_PERSONA
									WHEN egp.TIPO_PRESTAMO != 'GRUPO SOLIDARIO' AND egp.TIPO_PERSONA = 'J' THEN 'Jurídica'
									ELSE 'Natural'
							   END
		/*5*/,'NO_CREDITOS'	= Cant_Ptmo.CantPtmo 
		/*6*/,'DEUDA_TOTAL'	= DeudaTotal.DeudaTotalMN
		/*7*/,'COD_CREDITO'	= egp.NRO_PRESTAMO
		/*8*/,'TIPO_CREDITO'	= egp.DESCRIPCION_TIPO_CREDITO
	    /*9*/,'TIPO_PRODUCTO' = egp.PRODUCTO_AGRUPADOR
	    /*10*/,'SECTOR'		= egp.SECTOR
	    /*11*/,'FUENTE_FIN'	= 'Fondos Propios' --REVISAR CON NEGOCIOS Y/O FINANZAS SI ACA SE MANTENDRA IGUAL QUE EN LA CDR
	    /*12*/,'CODIGO_MUC'	= egp.RUBRO_CONTABLE
	    /*13*/,'MONTO_ORIGINAL' = CONVERT(NUMERIC(15,2), egp.IMPORTE_DESEMBOLSO_MO)
		/*14*/,'MONEDA' = CASE egp.CODIGO_MONEDA WHEN 1 THEN 'CORDOBAS' WHEN 2 THEN 'CORD MANT VALOR' WHEN 3 THEN 'DOLARES (USD)' END
		/*15*/,'SALDO_PRINCIPAL' = CONVERT (NUMERIC(15,2),(CASE 
															WHEN egp.CODIGO_MONEDA != 1 AND egp.SITUACION_PRESTAMO = 'Saneado' 
																THEN egp.SALDO_MO * dbo.FN_ObtenerTipoCambio(egp.FECHA_CASTIGO)
														    /* Aplicar para moneda 1,2,3 y creditos que no estan saneados */
														    ELSE egp.SALDO_MN
													  END)
										)
		/*16*/,'SALDO_INTERES' =  CASE WHEN egp.SITUACION_PRESTAMO = 'Saneado' THEN egp.INTERESES_SANEADOS_MN
									ELSE egp.DEVENGADO_INT_CTE_MN
								END 
		/*17*/,'Monto_Ult_Pago_Ppal' = egp.MTO_ULT_PAGO_CAPITAL
		/*18*/,'Monto_Ult_Pago_Int'  = ISNULL((SELECT TOP 1 SUM(bhp.INTERESPAGADO) --Se sumarizan todos los pagos a interes recibidos en la ultima fecha de pago
   											  FROM BS_HISTORIA_PLAZO bhp WITH (NOLOCK) 
											  WHERE bhp.SALDOS_JTS_OID =s.JTS_OID AND bhp.TIPOMOV='P' AND bhp.TZ_LOCK=0 AND bhp.INTERESPAGADO > 0
											  GROUP BY bhp.SALDOS_JTS_OID,  bhp.FECHAVALOR
											  ORDER BY bhp.FECHAVALOR DESC),0) 


		/*19*/,'FECHA_APROBACION'	 = FORMAT(ISNULL(sc.C5231,egp.FECHA_DESEMBOLSO),'dd/MM/yyyy')  --Si la fecha de aprobacion es nula, significa que es migrado de
		                                                                                 --abacus, para ese caso utilizo la fecha de desembolsos en saldo
		/*20*/,'FECHA_DESEMBOLSO'	 = ISNULL(FORMAT(egp.FECHA_DESEMBOLSO,'dd/MM/yyyy'),'')
		/*21*/,'FECHA_VENCIMIENTO'	 = (SELECT FORMAT( MAX(bp.C2302),'dd/MM/yyyy') FROM BS_PLANPAGOS bp with (nolock) WHERE bp.SALDO_JTS_OID = s.JTS_OID AND bp.TZ_LOCK =0 )
	    /*22*/,'PLAZO'			 = DATEDIFF(DAY,s.C1620,(	SELECT MAX(bp.C2302)  
														FROM BS_PLANPAGOS bp with (nolock) 
														WHERE bp.SALDO_JTS_OID = s.JTS_OID AND bp.TZ_LOCK =0 )
													  )
	    /*23*/,'Fecha_primer_pago'		 = FORMAT(egp.FECHA_1ERPAGO_PACTADO,'dd/MM/yyyy')
		/*24*/,'Fecha_ultimo_pago_ppal' = ISNULL(FORMAT(Bhp_Pagos.Fecha_Ult_Pago,'dd/MM/yyyy'),'')
		/*25*/,'Fecha_ultimo_pago_int' = ISNULL(FORMAT(Bhp_Pagos_Int.Fecha_Ult_Pago,'dd/MM/yyyy'),'')
		/*26*/,'FECHA_INGRESO_MORA_PPAL' = CASE 
											WHEN FORMAT(egp.FECHA_EMPESO_MORA_CAPITAL,'dd/MM/yyyy') = '01/01/1900' THEN ''
											ELSE FORMAT(egp.FECHA_EMPESO_MORA_CAPITAL,'dd/MM/yyyy')
										END
	    /*27*/,'FECHA_INGRESO_MORA_INT' =	CASE 
											WHEN FORMAT(egp.FECHA_EMPESO_MORA_INTERES,'dd/MM/yyyy') = '01/01/1900' THEN ''
											ELSE FORMAT(egp.FECHA_EMPESO_MORA_INTERES,'dd/MM/yyyy')
										END
		/*28*/,'Frecuencia_pago_ppal'	= EGP.FRECUENCIA_PAGO
		/*29*/,'Frecuencia_pago_int'	= EGP.FRECUENCIA_PAGO
		/*30*/,'CUOTAS_PROGRAMADAS'	= egp.CANTIDAD_CUOTAS_PACTADAS
		/*31*/,'CUOTAS_PAGADAS'		= egp.CUOTAS_PAGADAS
		/*32*/,'CUOTAS_VENCIDAS'		= egp.CANTIDAD_CUOTAS_VENCIDAS 
		/*33*/,'MODALIDAD' =	CASE s.C1677
								WHEN 'F' THEN 'Cuota Fija'
								WHEN 'H' THEN 'Decreciente'
								WHEN '' THEN 'Al Vencimiento'
								WHEN 'C' THEN 'Irregular'
								ELSE ''
							END  
	   /*34*/,'DIAS_GRACIA' = 0
	  ,'TIPO_TASA' = CASE WHEN /*cp.C6251*/egp.PRODUCTO LIKE '%COLABORADORES%' THEN 'Variable' ELSE 'Fija' END
	  ,'TASA_CONTRACTUAL' = CONVERT(NUMERIC(15,2), (CASE WHEN egp.SITUACION_PRESTAMO = 'Saneado' AND egp.TASA_INTERES = 0 THEN (SELECT hp.TASAINTERES FROM BS_HISTORIA_PLAZO hp WHERE (hp.TIPOMOV = 'A' OR hp.TIPOMOV = 'I') AND hp.SALDOS_JTS_OID = s.JTS_OID AND hp.TZ_LOCK = 0)
								 ELSE egp.TASA_INTERES
							END))
	  ,'TASA_VIGENTE' = CONVERT(NUMERIC(15,2), (CASE WHEN egp.CODIGO_ESTADO IN ('C','E') AND egp.TASA_INTERES = 0 THEN (SELECT hp.TASAINTERES FROM BS_HISTORIA_PLAZO hp WHERE (hp.TIPOMOV = 'A' OR hp.TIPOMOV = 'I') AND hp.SALDOS_JTS_OID = s.JTS_OID AND hp.TZ_LOCK = 0)
							 ELSE egp.TASA_INTERES
						END))
	  ,'Tasa_efectiva_vigente' = CONVERT(NUMERIC(15,2),  (POWER(1 + s.C6645 * 12.0 / 100 / 365, 365 / 1) - 1)* 100) 		
	  ,'TASA_MORA' =  CONVERT(NUMERIC(15,2),( CASE WHEN egp.CODIGO_ESTADO IN ('C','E') AND egp.TASA_MORA = 0 THEN (SELECT hp.TASAMORA FROM BS_HISTORIA_PLAZO hp WHERE (hp.TIPOMOV = 'A' OR hp.TIPOMOV = 'I') AND hp.SALDOS_JTS_OID = s.JTS_OID AND hp.TZ_LOCK = 0)
							 ELSE egp.TASA_MORA
					 END))
	  ,'TIPO_GARANTIA' = egp.TIPO_GARANTIA
	  ,'DESCRIPCION_GARANTIA' = dbo.FN_DescripcionGarantias(egp.NRO_PRESTAMO) --El mostrar las garantias concatenadas hace que la consulta dilate mas de 10 minutos
	  ,'VALOR_GARANTIA' = ISNULL(MtosGtias.MontoGarantias,0)
	  ,'MONTO_CUOTA' = CASE WHEN s.C1677 = 'F' THEN bpo.CuotaCapInt /*(SELECT (bpo.Capital+bpo.Intereses) 
													 FROM BS_PLANPAGOS_ORIGINAL bpo WITH (NOLOCK)
													 WHERE bpo.Saldos_JTS_OID = s.JTS_OID 
													   AND bpo.Numero_Cuota = 1
													   AND bpo.Capital > 0)*/
							ELSE 0
					   END
	  ,'CUOTA_TOTAL' = CASE WHEN s.C1677 = 'F' THEN bpo.CuotaCapInt /*(SELECT (bpo.Capital+bpo.Intereses) 
													 FROM BS_PLANPAGOS_ORIGINAL bpo WITH (NOLOCK)
													 WHERE bpo.Saldos_JTS_OID = s.JTS_OID 
													   AND bpo.Numero_Cuota = 1
													   AND bpo.Capital > 0)*/
													+
													ISNULL(gpco.Importe_Gastos
														   --(SELECT SUM(gpco.Importe_Gastos) 
															--FROM GASTOS_POR_CUOTA_ORIGINAL gpco WITH (NOLOCK)
															--WHERE gpco.Saldos_JTS_OID =s.JTS_OID AND gpco.Numero_Cuota = 1 GROUP BY gpco.Saldos_JTS_OID)
														   ,0)
							ELSE 0
					   END
	  ,'PRINCIPAL_CORRIENTE' = egp.SALDO_VIGENTE_MO * @TC
	  ,'PRINCIPAL_VENCIDO' = isnull((SELECT sum(C2309) FROM BS_PLANPAGOS p with (nolock)
 									 WHERE p.SALDO_JTS_OID=s.JTS_OID
 									   AND p.C2302 < @FechaCorte
 									   AND p.TZ_LOCK = 0
 									   AND p.C2309 > 0 
 									 ),0) * @TC
	  ,'Interes_Cte_Vgte' = isnull(hd.INTERES_DEVENG_VIGENTE_CONT * @TC,0) --Interes ordinario compensatorio solo la porcion corriente
	  ,'Interes_Cte_Vcdo' = (isnull(hd.INTERES_DEVENG_VENCIDO_CONT,0) --Interes ordinario compensatorio solo la porcion vencida (Interes vencido)
 							 + (isnull(hd.MORA_TASA_INT_DEVENG_VENC_CONT,0) + isnull(hd.MORA_TASA_INT_DEVENG_VIGE_CONT,0)))--Interes ordinario en mora (Mora calculada a la tasa de interes corriente)
 							 * @TC
	  ,'INTERES_MORATORIO' = egp.INTERES_MORATORIO_MN
	  ,'FECHA_PROX_PAGO_PPAL' = ISNULL(PPCapital.ProxPagoPrinc,'')
	  ,'FECHA_PROX_PAGO_INT' = ISNULL(PPInteres.ProxPagoInt,'')
	  ,'DIAS_MORA_PRINCIPAL' = ISNULL(bpcap.DiasMoraCap,0)
	  ,'DIAS_MORA_INTERESES' = ISNULL(bpint.DiasMoraInt,0)
	  ,'Clasificacion' = CASE egp.CLASIFICACION_PRESTAMO WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3 WHEN 'D' THEN 4 WHEN 'E' THEN 5 ELSE '' END--calif.ValorSIBOIF
	  ,'Clasificacion_Cliente' = CASE egp.CALIFICACION_UTILIZADA WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3 WHEN 'D' THEN 4 WHEN 'E' THEN 5 ELSE '' END
	 -- ,'CALIF_UTILIZADA' = CASE egp.CALIFICACION_UTILIZADA WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3 WHEN 'D' THEN 4 WHEN 'E' THEN 5 ELSE '' END
	  ,'PROVISION' = egp.PROVISION_MN
	  ,'SUCURSAL' = egp.DESC_SUCURSAL_PRESTAMO
	  ,'ASESOR_CREDITO' = egp.ANALISTA
	  --,egp.JTS_OID

/* Campos Internos */
	  ,'Interno_FechaCorte' =		@FechaCorte
	  ,'Interno_ControlVersion' =	@ControlVersion
--INTO TMP_SIBOIF	  
FROM SALDOS s WITH (NOLOCK)
  INNER JOIN #TempEGP egp ON s.JTS_OID = egp.JTS_OID --AND s.C9314 = 5 
  INNER JOIN SL_SOLICITUDCREDITO sc WITH (NOLOCK) ON s.C1704 = sc.C5000 --Para obtener la fecha de aprobacion del credito
  INNER JOIN CL_CLIENTES cc ON s.C1803 = cc.C0902
  INNER JOIN (SELECT COUNT(egp2.CODIGO_CLIENTE) CantPtmo,egp2.CODIGO_CLIENTE
              FROM #TempEGP egp2
              GROUP BY egp2.CODIGO_CLIENTE
			 ) AS Cant_Ptmo ON egp.CODIGO_CLIENTE = Cant_Ptmo.CODIGO_CLIENTE 
  INNER JOIN (SELECT SUM(CASE WHEN egp2.CODIGO_MONEDA != 1 AND egp2.SITUACION_PRESTAMO = 'Saneado' 
								THEN egp2.SALDO_MO * dbo.FN_ObtenerTipoCambio(egp2.FECHA_CASTIGO)
							/* Aplicar para moneda 1,2,3 y creditos que no estan saneados */
							ELSE egp2.SALDO_MN
					   END) AS DeudaTotalMN
				    ,egp2.CODIGO_CLIENTE
              FROM #TempEGP egp2
              GROUP BY egp2.CODIGO_CLIENTE
			 ) AS DeudaTotal ON egp.CODIGO_CLIENTE = DeudaTotal.CODIGO_CLIENTE
  OUTER APPLY (SELECT MAX(bshp.FECHAVALOR) AS Fecha_Ult_Pago
				     ,bshp.SALDOS_JTS_OID  
 			   FROM bs_historia_plazo bshp WITH (NOLOCK) 
 			   WHERE bshp.SALDOS_JTS_OID = egp.JTS_OID AND bshp.CAPITALPAGADO > 0 AND bshp.tipomov = 'P' AND bshp.TZ_LOCK = 0
               GROUP BY bshp.SALDOS_JTS_OID) AS Bhp_Pagos --ON egp.JTS_OID = Bhp_Pagos.SALDOS_JTS_OID
  OUTER APPLY (SELECT MAX(bshp.FECHAVALOR) AS Fecha_Ult_Pago
				     ,bshp.SALDOS_JTS_OID  
 			   FROM bs_historia_plazo bshp WITH (NOLOCK) 
 			   WHERE bshp.SALDOS_JTS_OID = egp.JTS_OID AND bshp.INTERESPAGADO > 0 AND bshp.tipomov = 'P' AND bshp.TZ_LOCK = 0
               GROUP BY bshp.SALDOS_JTS_OID) AS Bhp_Pagos_Int --ON egp.JTS_OID = Bhp_Pagos.SALDOS_JTS_OID               

  OUTER APPLY (SELECT SUM(CASE WHEN gg.GAR_MONEDA = 2 THEN ISNULL(gg.GAR_VALORGRAVAMEN,0) * dbo.FN_ObtenerTipoCambio(gg.GAR_FECHA)
							 WHEN gg.GAR_MONEDA = 3 THEN ISNULL(gg.GAR_VALORGRAVAMEN,0) * @TC
							 WHEN gg.GAR_MONEDA = 1 THEN ISNULL(gg.GAR_VALORGRAVAMEN,0)
							 ELSE 0
						END) AS MontoGarantias
				     ,gr.NROSOLICITUD
               FROM GR_RELACIONGTIACREDSOLIC gr WITH (NOLOCK) 
               INNER JOIN GR_GARANTIAS gg WITH (NOLOCK) ON gr.NROGARANTIA = gg.NROGARANTIA 
               WHERE gr.NROSOLICITUD = s.C1704 AND gr.TZ_LOCK = 0 AND gg.TZ_LOCK = 0
               GROUP BY gr.NROSOLICITUD
			  ) AS MtosGtias 
  OUTER APPLY (SELECT rpd.NRODOCUMENTO AS NumDocumento,gs.NRO_PRESTAMO, rpd.TIPODOC, TIPO_PERSONA ='Natural'
			   FROM #FN_GS_Miembros gs 
				 INNER JOIN CL_RELGSCLTE gc WITH (NOLOCK) ON gs.COD_CLIENTE_M = gc.C3199 AND gc.C3201 = 'S' AND gc.C3210 = 'AC' 
				 INNER JOIN CL_RELPERDOC rpd WITH (NOLOCK) ON gc.C3199 = rpd.IDPERSONA AND rpd.ESTADO = 'A' AND rpd.PRINCIPAL = 'S'
	           WHERE gs.SALDO_JTS_OID = egp.JTS_OID AND gc.C3198 = egp.CODIGO_CLIENTE AND gc.TZ_LOCK = 0) AS CoordGrupo
  OUTER APPLY (SELECT TOP(1) SUM(bpo.Capital+bpo.Intereses) AS CuotaCapitalInteres
					,bpo.Saldos_JTS_OID
               FROM BS_PLANPAGOS_ORIGINAL bpo WITH (NOLOCK) 
               WHERE bpo.Saldos_JTS_OID = egp.JTS_OID
			     AND bpo.Capital > 0
               GROUP BY bpo.Saldos_JTS_OID) AS CuotaNoCargos --ON egp.JTS_OID = CuotaNoCargos.CuotaCapitalInteres
  OUTER APPLY (SELECT FORMAT(min(bp.C2302),'dd/MM/yyyy') AS ProxPagoPrinc,bp.SALDO_JTS_OID
               FROM BS_PLANPAGOS bp WITH (NOLOCK)
               WHERE bp.SALDO_JTS_OID = egp.JTS_OID 
                 AND bp.TZ_LOCK = 0 
                 AND bp.c2309 > 0
               GROUP BY bp.SALDO_JTS_OID) AS PPCapital --ON egp.JTS_OID = PPCapital.SALDO_JTS_OID 
  OUTER APPLY (SELECT FORMAT(min(bp.C2302),'dd/MM/yyyy') AS ProxPagoInt,bp.SALDO_JTS_OID
               FROM BS_PLANPAGOS bp WITH (NOLOCK) 
               WHERE bp.SALDO_JTS_OID = egp.JTS_OID 
                 AND bp.TZ_LOCK = 0 
                 AND bp.c2310 > 0
               GROUP BY bp.SALDO_JTS_OID) AS PPInteres --ON egp.JTS_OID = PPInteres.SALDO_JTS_OID
  OUTER APPLY (SELECT bp.SALDO_JTS_OID,DATEDIFF(DAY,MIN(bp.C2302),p.FECHAPROCESO) AS DiasMoraInt
               FROM BS_PLANPAGOS bp,PARAMETROS p
               WHERE s.JTS_OID = bp.SALDO_JTS_OID
                 AND bp.C2310 > 0 --Que aun este pendiente de pago el capital
                 AND bp.C2302 < p.FECHAPROCESO --Que la fecha de la cuota sea menor a la fecha de corte (este vencida)
                 AND bp.TZ_LOCK = 0
               GROUP BY bp.SALDO_JTS_OID,p.FECHAPROCESO
              ) bpint
  OUTER APPLY (SELECT bp.SALDO_JTS_OID,DATEDIFF(DAY,MIN(bp.C2302),p.FECHAPROCESO) AS DiasMoraCap
               FROM BS_PLANPAGOS bp,PARAMETROS p
               WHERE s.JTS_OID = bp.SALDO_JTS_OID
                 AND bp.C2309 > 0 --Que aun este pendiente de pago el capital
                 AND bp.C2302 < p.FECHAPROCESO --Que la fecha de la cuota sea menor a la fecha de corte (este vencida)
                 AND bp.TZ_LOCK = 0
               GROUP BY bp.SALDO_JTS_OID,p.FECHAPROCESO
              ) bpcap
  OUTER APPLY (SELECT hid.INTERES_DEVENG_VIGENTE_CONT,hid.INTERES_DEVENG_VENCIDO_CONT,hid.MORA_TASA_INT_DEVENG_VENC_CONT,hid.MORA_TASA_INT_DEVENG_VIGE_CONT
               FROM HISTORICO_DEVENGAMIENTO hid WITH (NOLOCK)
               WHERE hid.SALDO_JTS_OID = s.JTS_OID AND hid.FECHA = @FechaCorte) hd
  OUTER APPLY (SELECT Importe_Gastos,gpco.Saldos_JTS_OID
			   FROM #GASTOS_POR_CUOTA_ORIGINAL gpco WITH (NOLOCK)
			   WHERE gpco.Saldos_JTS_OID = s.JTS_OID) AS gpco
  OUTER APPLY (	
  			  SELECT TOP 1 *  FROM (
  				SELECT (bpo.Capital+bpo.Intereses) AS CuotaCapInt
  				,bpo.Numero_Cuota 
				FROM BS_PLANPAGOS_ORIGINAL bpo WITH (NOLOCK)
				WHERE bpo.Saldos_JTS_OID = s.JTS_OID 
				AND bpo.Numero_Cuota = 2 /* TODO: Pendiente consultar por que para la mayoria de los casos se debe seleccionar la cuota 2 en vez de la 1 */
				AND (bpo.Capital+bpo.Intereses) > 0
				UNION ALL
				SELECT (bpo.Capital+bpo.Intereses) AS CuotaCapInt 
				,bpo.Numero_Cuota 
				FROM BS_PLANPAGOS_ORIGINAL bpo WITH (NOLOCK)
				WHERE bpo.Saldos_JTS_OID = s.JTS_OID 
				AND bpo.Numero_Cuota = 1
				AND (bpo.Capital+bpo.Intereses) > 0
				)x
  			  ORDER BY x.Numero_Cuota desc
			 ) bpo
WHERE s.TZ_LOCK = 0

