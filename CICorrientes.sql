USE [Tarea_3]
GO
/****** Object:  StoredProcedure [dbo].[CargosInteresesCorr]    Script Date: 29/5/2023 19:58:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CargosInteresesCorr]
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
	, @idProceso INT = 7
	, @CurrentEventLogId INT
	, @LastLoId INT
	, @SaldoFin MONEY
	, @idCTM INT
	, @Monto INT

	DECLARE @SaldoCorriente TABLE
	(
		  Sec INT IDENTITY(1,1)
		, idCT VARCHAR(128)
		, idCTM INT
		, MontoDebitoIC MONEY
		, TipoCTM VARCHAR(128)
		, SaldoAcumulado MONEY
		, Porcentaje MONEY
	);

	IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) 
	AND (EvenDate= @InFechaOperacion) AND (LastIdProccess=LastIdToBeProcessed))
		BEGIN
			SET @OutResult = 50023
		END

		INSERT INTO @SaldoCorriente (idCT, idCTM ,MontoDebitoIC, TipoCTM, SaldoAcumulado, porcentaje)
		SELECT
			cm.idCT
			, cm.id
			, (cm.Saldo / vrxp.valor / 100 / 30)
			, tctm.Nombre AS TipoCTM
			, cm.Interes_AcuCorr
			, vrxp.valor AS porcentaje
		FROM dbo.CuentaMaest cm
			INNER JOIN dbo.TipoCuentaTM tctm ON cm.idTipoCTM = tctm.id
			INNER JOIN dbo.vistaReglaXPorc vrxp ON cm.idTipoCTM = vrxp.idTipoCTM
		WHERE vrxp.Nombre = 'Tasa de interes corriente' AND cm.Saldo > 0;

		SELECT @hi = MAX(Sec) FROM @SaldoCorriente
		
		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) 
		AND (EvenDate= @InFechaOperacion))
				BEGIN
					SELECT @LastLoId = EL.LastIdProccess
					, @CurrentEventLogId = EL.id
					FROM dbo.EventLog EL
					WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
					SELECT @lo = E.Sec+1
					FROM @SaldoCorriente E
					WHERE E.Sec=@LastLoId
				END

		ELSE
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
				VALUES (@idProceso, @InFechaOperacion, 'Proceso calculo intereses corrientes', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END

		WHILE(@lo <= @hi)
			BEGIN
				SELECT 
					@SaldoFin = SaldoAcumulado + MontoDebitoIC 
					, @idCTM = idCTM
					, @Monto = SaldoAcumulado
				FROM @SaldoCorriente 
				WHERE Sec = @lo

				BEGIN TRANSACTION CalculoCorriente

					INSERT INTO dbo.MovInteCorr
					(
					idCTM
					, idTipoMov
					, Descripcion
					, Fecha
					, Monto
					, Nuevo_InteAcuCorr
					)
					VALUES
					(
					@idCTM
					, (SELECT id FROM dbo.TMTI WHERE Accion = 'Suma')
					, 'Intereses Corrientes'
					, @InFechaOperacion
					, @Monto
					, @SaldoFin
					)
				
					UPDATE dbo.CuentaMaest
					SET 
						Interes_AcuCorr = @SaldoFin
					WHERE @idCTM = id
				
					UPDATE dbo.EventLog
					SET 
						LastIdProccess = @lo
					WHERE id = @CurrentEventLogId;

				COMMIT TRANSACTION CalculoCorriente

				SET @lo = @lo+1
			END
END TRY
BEGIN CATCH
	
	IF @@TRANCOUNT > 0
	BEGIN
		ROLLBACK TRANSACTION CalculoCorriente
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
