USE [Tarea_3]
GO
/****** Object:  StoredProcedure [dbo].[EmisionEC]    Script Date: 26/5/2023 13:06:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[EmisionEC]
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
		, @idProceso INT = 12
		, @CurrentEventLogId INT
		, @LastLoId INT
		, @idCTM INT
		, @idCTA INT
		, @idTipoCTM INT
		, @EsMaestr BIT
		, @idTarjFisi INT
		, @idCT INT
		, @idSubEstadCuent INT
		, @idEstadCuent INT
		, @CSValorCTM MONEY
		, @CSValorCTA MONEY
		, @CSFraude MONEY
		, @CargoATM MONEY = 0
		, @CargoVENT MONEY = 0
		, @Cantidad INT
		, @InterAcuCorr MONEY = 0
		, @InterAcuMora MONEY
		, @SaldoF MONEY
		, @FechaPagoMin DATE
		, @PagoMin MONEY
		, @idTipoMov INT
		, @idTF INT
		, @SaldoCopia MONEY

		DECLARE 
		@ECC TABLE
		(
			Sec INT IDENTITY(1,1)
			, Codigo VARCHAR(128)
			, idCT INT
			, Maestra BIT
			, FechaCreacion DATE
		)

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) 
		AND (EvenDate= @InFechaOperacion) AND (LastIdProccess=LastIdToBeProcessed))
		BEGIN
			SET @OutResult = 50022
			RETURN
		END

		INSERT INTO @ECC (Codigo, idCT, Maestra, FechaCreacion)
		SELECT 
			Codigo
			, id
			, Es_Maestra
			, Fecha_Creacion
		FROM dbo.Cuenta C
		WHERE (dbo.CumpleFecha(@InFechaOperacion, C.Fecha_Creacion) = 1)

		SELECT @hi = MAX(E.Sec) FROM @ECC E
		
		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) 
		AND (EvenDate= @InFechaOperacion))
		BEGIN
			SELECT 
			@LastLoId =EL.LastIdProccess
			, @CurrentEventLogId = EL.id
			FROM dbo.EventLog EL
			WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
			SELECT @lo = E.Sec+1
			FROM @ECC E
			WHERE E.Sec=@LastLoId
		END
		
		ELSE
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
				VALUES (@idProceso, @InFechaOperacion, 'Emision EC', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END

		WHILE(@lo <= @hi)
		BEGIN 	
			SELECT 
			@idCT = F.idCT
			, @EsMaestr = C.Es_Maestra
			FROM @ECC F 
			INNER JOIN  dbo.Cuenta C ON C.id = F.idCT
			WHERE (@lo = F.idCT)

			IF (@EsMaestr = 1)
				BEGIN
					SELECT 
					@InterAcuMora = Interes_AcuMora 
					, @idCTM = id
					, @idTipoCTM = idTipoCTM
					, @InterAcuCorr = Interes_AcuCorr
					FROM dbo.CuentaMaest 
					WHERE @idCT = idCT

					SELECT 
					@idEstadCuent= MAX(E.id)
					FROM dbo.EstadCuenta E
					WHERE(E.idCTM = @idCTM)

					SELECT
					@idTF = id
					FROM dbo.TarjetaFis 
					WHERE @idCT = idCT

					SELECT
					@CSValorCTM = vm.valor
					FROM dbo.vistaReglaxMoney vm
					WHERE vm.Nombre = 'Cargos Servicio Mensual CTM' 
					AND 3 = idTipoCTM

					SELECT
					@CSValorCTA = vm.valor
					FROM dbo.vistaReglaxMoney vm
					WHERE vm.Nombre = 'Cargos Servicio Mensual CTA'
					AND 3 = idTipoCTM

					SELECT
					@CSFraude = vm.valor
					FROM dbo.vistaReglaxMoney vm
					WHERE vm.Nombre = 'Cargo Seguro Contra Fraudes'
					AND 3 = idTipoCTM
				END
			ELSE
			BEGIN
				SELECT 
				@idCTM = C.idCTM
				, @idCTA = C.id
				FROM dbo.CuentaAdi C
				WHERE C.idCT = @idCT
			END

					SELECT 
					@Cantidad = COUNT(idCTM)
					FROM dbo.CuentaAdi ad
					WHERE @idCTM = ad.idCTM 

					SELECT
					@SaldoF = Saldo
					, @FechaPagoMin = FechaPagoMin
					, @PagoMin = PagoMin
					FROM dbo.EstadCuenta
					WHERE @idEstadCuent = id

					SET @CSValorCTA = @CSValorCTA*@Cantidad
					SET @SaldoCopia = @SaldoF
					SET @SaldoF = @SaldoF+@InterAcuCorr-@InterAcuMora
								 -@CSValorCTM-@CSValorCTA-@CSFraude
								 -@CargoATM-@CargoVENT

			SELECT 
			@idTipoMov = id 
			FROM dbo.TipoMov m 
			WHERE m.Nombre = 'Intereses Corrientes sobre Saldo'

			BEGIN TRANSACTION EmisionEC

			IF (@EsMaestr = 1)
			BEGIN
				SET @SaldoCopia = @SaldoCopia - @CSValorCTM
				INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
				VALUES
				(
				@idTipoMov
				, @idTF
				, 'Cargos Servicio Mensual CTM'
				, @InFechaOperacion
				, @CSValorCTM 
				, 'AUTOMATICO'
				, @SaldoCopia
				)
				SET @SaldoCopia = @SaldoCopia - @CSValorCTA
				INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
				VALUES
				(
				@idTipoMov
				, @idTF
				, 'Cargos Servicio Mensual CTA'
				, @InFechaOperacion
				, @CSValorCTA 
				, 'AUTOMATICO'
				, @SaldoCopia 
				)
				SET @SaldoCopia = @SaldoCopia - @CSFraude
				INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
				VALUES
				(
				@idTipoMov
				, @idTF
				, 'Cargo Seguro Contra Fraudes'
				, @InFechaOperacion
				, @CSFraude 
				, 'AUTOMATICO'
				, @SaldoCopia
				)

				IF ((SELECT valor FROM vistaReglaXQOper WHERE @idTipoCTM = idTipoCTM 
				AND Nombre = 'Cantidad de opraciones en ATM') < (SELECT CantOpVent
				FROM dbo.EstadCuenta WHERE idCTM = @idCTM AND id = @idEstadCuent))
				BEGIN
					SELECT 
					@CargoATM = vm.valor
					FROM dbo.vistaReglaxMoney vm
					WHERE @idTipoCTM = idTipoCTM AND vm.Nombre = 'Multa exceso de operaciones ATM'

					SET @SaldoCopia = @SaldoCopia - @CargoATM
						
					INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
					VALUES
					(
					@idTipoMov
					, @idTF
					, 'Multa exceso de operaciones Ventanilla'
					, @InFechaOperacion
					, @CargoATM 
					, 'AUTOMATICO'
					, @SaldoCopia
					)
				END
				
				IF ((SELECT valor FROM vistaReglaXQOper WHERE @idTipoCTM = idTipoCTM 
				AND Nombre = 'Cantidad de operacion en Ventanilla') < (SELECT CantOpVent
				FROM dbo.EstadCuenta WHERE idCTM = @idCTM AND id = @idEstadCuent))
				BEGIN
					SELECT 
					@CargoVENT = vm.valor
					FROM dbo.vistaReglaxMoney vm
					WHERE @idTipoCTM = idTipoCTM AND vm.Nombre = 'Multa exceso de operaciones Ventanilla'

					SET @SaldoCopia = @SaldoCopia - @CargoVENT

					INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
					VALUES
					(
					@idTipoMov
					, @idTF
					, 'Multa exceso de operaciones Ventanilla'
					, @InFechaOperacion
					, @CargoVENT 
					, 'AUTOMATICO'
					, @SaldoCopia 
					)
				END
			
				IF ((SELECT Saldo - SumaPagosMin FROM dbo.EstadCuenta ect WHERE id = @idEstadCuent) < 0)
				BEGIN
					SET @InterAcuCorr = @SaldoCopia - @InterAcuCorr
				END

				SET @SaldoCopia = @SaldoCopia - @InterAcuCorr
				INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
				VALUES
				(
				@idTipoMov
				, @idTF
				, 'Credito Interes Diario'
				, @InFechaOperacion
				, @InterAcuCorr 
				, 'AUTOMATICO'
				, @SaldoCopia
				)
			
				SET @SaldoCopia = @SaldoCopia - @InterAcuMora
				INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
				VALUES
				(
				@idTipoMov
				, @idTF
				, 'Debito por Redencion'
				, @InFechaOperacion
				, @InterAcuMora
				, 'AUTOMATICO'
				, @SaldoCopia
				)
			END

			

			IF (@EsMaestr = 1)
				BEGIN
					INSERT INTO dbo.EstadCuenta
						(
						Saldo
						, Fecha
						, FechaPagoMin
						, PagoMin
						, idCTM
						, interesCA
						, interesMA
						, CantOpATM
						, CantOpVent
						, SumaPagosMin
						, CantPagoMes
						, SumaPagoMes
						, SumaCompra
						, CantCompras
						, SumaRetiros
						, CantRetiros
						, SumaTodosCred
						, CantTodosCred
						, SumaTodosDeb
						, CantTodosDeb
						)
					VALUES
						(
						@SaldoF
						, @InFechaOperacion
						, @FechaPagoMin
						, @PagoMin
						, @idCTM
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						, 0
						);

					UPDATE dbo.CuentaMaest
					SET
					Saldo = @SaldoF
					, Interes_AcuCorr = @InterAcuCorr
					, Interes_AcuMora = @InterAcuMora
					WHERE @idCT = idCT
				END
				ELSE
				BEGIN
					INSERT INTO dbo.SubEstadCuent 
					(
					Fecha
					, idCTA
					, CantOpATM
					, CantOpVent
					, SumaCompra
					, CantCompra
					, SumaRetiros
					, CantRetiros
					, SumaTodosCred
					, SumaTodosDeb
					)
					VALUES 
					(
					@InFechaOperacion
					, @idCTA
					, 0
					, 0
					, 0
					, 0
					, 0
					, 0
					, 0
					, 0
					)
				END
			
			UPDATE dbo.EventLog
			SET LastIdProccess = @lo
			WHERE(id = @CurrentEventLogId)
			COMMIT TRANSACTION EmisionEC
			SET @lo = @lo+1
		END
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION EmisionEC
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
			SET @OutResult =50225
	END CATCH
	SET NOCOUNT OFF
END


