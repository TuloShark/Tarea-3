USE [Tarea_3]
GO
/****** Object:  StoredProcedure [dbo].[CargosInteresesMora]    Script Date: 29/5/2023 19:59:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CargosInteresesMora]
(
	@InFechaOperacion DATE
	, @OutResult INT OUTPUT
)
AS
BEGIN
	BEGIN TRY
	SET NOCOUNT ON
		DECLARE 
		  @lo INT
		, @hi INT
		, @idProceso INT = 8
		, @CurrentEventLogId INT
		, @LastLoId INT
		, @SaldoFin MONEY
		, @MontoPagoMinimoMora MONEY
		, @MontoDIM MONEY
		, @Porcentaje MONEY
		, @Monto MONEY
		, @idCTM INT

	DECLARE @SaldoMora TABLE
	(
		  Sec INT IDENTITY(1,1)
		, idCT VARCHAR(128)
		, idCTM INT
		, TipoCTM VARCHAR(128)
		, SaldoAcumulado MONEY
		, Porcentaje MONEY
		, fechaPagoMinimo DATE
		, SumaPago MONEY
		, PagoMin MONEY
	);

	IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) 
	AND (EvenDate= @InFechaOperacion) AND (LastIdProccess=LastIdToBeProcessed))
		BEGIN
			SET @OutResult = 50023
		END

		INSERT INTO @SaldoMora (idCT, idCTM, TipoCTM, SaldoAcumulado, porcentaje, fechaPagoMinimo, SumaPago, PagoMin)
		SELECT
			cm.idCT
			, cm.id
			, tctm.Nombre AS TipoCTM
			, cm.Interes_AcuMora
			, vrxp.valor AS porcentaje
			, ect.FechaPagoMin AS fechaPagoMinimo
			, ect.SumaPagoMes
			, ect.PagoMin
		FROM dbo.CuentaMaest cm
			INNER JOIN dbo.TipoCuentaTM tctm ON cm.idTipoCTM = tctm.id
			INNER JOIN dbo.vistaReglaXPorc vrxp ON cm.idTipoCTM = vrxp.idTipoCTM
			INNER JOIN dbo.EstadCuenta ect ON cm.idCT = ect.idCTM
		WHERE vrxp.Nombre = 'intereses moratorios' AND @InFechaOperacion > ect.FechaPagoMin AND ect.PagoMin > ect.SumaPagoMes;

		SELECT @hi = MAX(Sec) FROM @SaldoMora
		
		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) 
		AND (EvenDate= @InFechaOperacion))
				BEGIN
					SELECT @LastLoId = EL.LastIdProccess
					, @CurrentEventLogId = EL.id
					FROM dbo.EventLog EL
					WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
					SELECT @lo = E.Sec+1
					FROM @SaldoMora E
					WHERE E.Sec=@LastLoId
				END

		ELSE
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
				VALUES (@idProceso, @InFechaOperacion, 'Proceso calculo intereses moratorios', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END

		WHILE(@lo <= @hi)
			BEGIN
				SELECT 
					@MontoPagoMinimoMora = sm.PagoMin - sm.SumaPago
					, @Porcentaje = sm.porcentaje
					, @MontoDIM = @MontoPagoMinimoMora / @Porcentaje / 100 / 30
					, @SaldoFin = sm.SaldoAcumulado + @MontoDIM
					, @Monto = sm.SaldoAcumulado
					, @idCTM = idCTM
				FROM @SaldoMora sm
				WHERE Sec = @lo

				BEGIN TRANSACTION CalculoMora

					INSERT INTO dbo.MovInteMora
					(
					idCTM
					, idTipoMov
					, Descripcion
					, Fecha
					, Monto
					, Nuevo_InteAcuMora
					)
					VALUES
					(
					@idCTM
					, (SELECT id FROM dbo.TMTI WHERE Accion = 'Resta')
					, 'Intereses Moratorios'
					, @InFechaOperacion
					, @Monto
					, @SaldoFin
					)
				
					UPDATE dbo.CuentaMaest
					SET 
						Interes_AcuMora = @SaldoFin
					WHERE @idCTM = id

					UPDATE dbo.EventLog
					SET 
						LastIdProccess = @lo
					WHERE id = @CurrentEventLogId;

				COMMIT TRANSACTION CalculoMora
				
				SET @lo = @lo+1
			END
END TRY
BEGIN CATCH
	
	IF @@TRANCOUNT > 0
	BEGIN
		ROLLBACK TRANSACTION CalculoMora
	END 
	INSERT INTO dbo.DBErrors
		(
		[UserName]
		, [ErrorNumber]
		, [ErrorState]
		, [ErrorSeverity]
		, [ErrorLine]
		, [ErrorProcedure]
		, [ErrorMessage]
		, [ErrorDateTime]
		)
		VALUES 
		(
		SUSER_SNAME()
		, ERROR_NUMBER()
		, ERROR_STATE()
		, ERROR_SEVERITY()
		, ERROR_LINE()
		, ERROR_PROCEDURE()
		, ERROR_MESSAGE()
		, GETDATE()
		);
		SET @OutResult =500207

END CATCH
END