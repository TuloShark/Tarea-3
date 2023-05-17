USE [Tarea_3]
GO

/****** Object:  StoredProcedure [dbo].[CargosInteresesCorr]    Script Date: 17/5/2023 10:23:14 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CargosInteresesCorr]
AS
BEGIN
SET NOCOUNT ON
	DECLARE 
	@InFechaOperacion DATE
	, @lo INT
	, @hi INT
	, @SaldoFin MONEY

		DECLARE @SaldoCorriente TABLE
		(
			Sec INT IDENTITY(1,1)
			, idCT VARCHAR(128)
			, MontoDebitoIC MONEY
			, TipoCTM VARCHAR(128)
			, SaldoAcumulado MONEY
			, Porcentaje MONEY
		);

		INSERT INTO @SaldoCorriente (idCT, MontoDebitoIC, TipoCTM, SaldoAcumulado, porcentaje)
		SELECT
			cm.idCT
			, (cm.Saldo / vrxp.valor / 100 / 30)
			, tctm.Nombre AS TipoCTM
			, cm.Interes_AcuCorr
			, vrxp.valor AS porcentaje
		FROM dbo.CuentaMaest cm
			INNER JOIN dbo.TipoCuentaTM tctm ON cm.idTipoCTM = tctm.id
			INNER JOIN dbo.vistaReglaXPorc vrxp ON cm.idTipoCTM = vrxp.idTipoCTM
		WHERE vrxp.Nombre = 'Tasa de interes corriente' AND cm.Saldo > 0;


		SELECT @hi = MAX(Sec) FROM @SaldoCorriente
		SELECT @lo = MIN(Sec) FROM @SaldoCorriente

		WHILE(@lo <= @hi)
			BEGIN
				SELECT @SaldoFin = SaldoAcumulado + MontoDebitoIC 
				FROM @SaldoCorriente 
				WHERE SEC = @lo
				
				UPDATE dbo.CuentaMaest
				SET 
					Interes_AcuCorr = @SaldoFin
			END
END
GO


