USE [Tarea_3]
GO

/****** Object:  StoredProcedure [dbo].[CargosInteresesMora]    Script Date: 17/5/2023 10:23:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CargosInteresesMora]
AS
BEGIN
SET NOCOUNT ON
	DECLARE 
	@InFechaOperacion DATE
	, @lo INT
	, @hi INT
	, @SaldoFin MONEY

		DECLARE @SaldoMora TABLE
		(
			Sec INT IDENTITY(1,1)
			, idCT VARCHAR(128)
			, MontoDebitoIM MONEY
			, TipoCTM VARCHAR(128)
			, SaldoAcumulado MONEY
			, Porcentaje MONEY
		);

		INSERT INTO @SaldoMora (idCT, MontoDebitoIM, TipoCTM, SaldoAcumulado, porcentaje)
		SELECT
			cm.idCT
			, (cm.Saldo / vrxp.valor / 100 / 30)
			, tctm.Nombre AS TipoCTM
			, cm.Interes_AcuMora
			, vrxp.valor AS porcentaje
		FROM dbo.CuentaMaest cm
			INNER JOIN dbo.TipoCuentaTM tctm ON cm.idTipoCTM = tctm.id
			INNER JOIN dbo.vistaReglaXPorc vrxp ON cm.idTipoCTM = vrxp.idTipoCTM
		WHERE vrxp.Nombre = 'Tasa de interes corriente' AND 'SumaPagos' < 'MontoPagoMinimo' AND @InFechaOperacion > 'PagoMinimo' ;


		SELECT @hi = MAX(Sec) FROM @SaldoMora
		SELECT @lo = MIN(Sec) FROM @SaldoMora

		WHILE(@lo <= @hi)
			BEGIN
				SELECT @SaldoFin = SaldoAcumulado + MontoDebitoIM 
				FROM @SaldoMora 
				WHERE SEC = @lo
				
				UPDATE dbo.CuentaMaest
				SET 
					Interes_AcuCorr = @SaldoFin
			END
END
GO


