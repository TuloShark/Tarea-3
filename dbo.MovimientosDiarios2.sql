USE [Tarea_3]
GO
/****** Object:  StoredProcedure [dbo].[ProcesamientoMovimientos]    Script Date: 25/5/2023 07:20:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[ProcesamientoMovimientos]
(
	@InFechaOperacion DATE
	, @OutResult INT OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		DECLARE @lo INT
		, @hi INT
		, @idProceso INT = 6
		, @CurrentEventLogId INT
		, @LastLoId INT
		, @idTipoMov INT
		, @idTarjFisi INT
		, @FechaMov DATE
		, @Monto MONEY
		, @Descripcion VARCHAR(128)
		, @Referencia VARCHAR(128)
		, @idCT INT 
		, @EsMaestr BIT
		, @idCTM INT
		, @SumaCred INT
		, @SumaDeb INT
		, @SumaRetir INT
		, @SumaPago INT
		, @SumaCompras INT
		, @OperacionATM INT
		, @OperacionVent INT
		, @NuevoMonto Money
		, @idEstadCuent INT
		, @idSubEstadCuent INT
		, @SumaMin INT

		DECLARE @xmlData XML -- Se declara la variable XML
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB) -- Ruta del archivo.
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);
		--Tablas variables para obtener datos o precalcular datos
		DECLARE @TableMovProces TABLE
		(
			Sec INT IDENTITY(1,1)
			, idTipoMov INT
			, idTarjFisi INT 
			, FechaMov DATE
			, Monto MONEY
			, Descripcion VARCHAR(128)
			, Referencia VARCHAR(128)
		);
		DECLARE @TablaDatosEc TABLE 
		(
			Sec INT	
			, idEC INT 
			, CantOpATM INT
			, CantOpVent INT
			, SumaPagosMin MONEY
			, CantPagoMes INT
			, SumaPagoMes MONEY
			, SumaCompra MONEY
			, CantCompras INT
			, SumaRetiros MONEY
			, CantRetiros INT
			, SumaTodosCred MONEY
			, CantTodosCred INT
			, SumaTodosDeb MONEY
			, CantTodosDeb INT
		);
		DECLARE @TablaSubEcCalc TABLE 
		(
			SEC INT 
			, idSubEC INT 
			, CantOpATM INT
			, CantOpVent INT
			, CantCompras INT
			, SumaCompra MONEY 
			, SumaRetiros MONEY
			, CantRetiros INT
			, SumaTodosCred MONEY
			, SumaTodosDeb MONEY
		);

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion) 
									AND (LastIdProccess=LastIdToBeProcessed))
		BEGIN
			SET @OutResult = 50022
			RETURN
		END

		INSERT INTO @TableMovProces (idTipoMov, idTarjFisi, FechaMov, Monto, Descripcion, Referencia)
		SELECT 
			M.id AS [idTipoMov]
			, F.id AS [idTarjFisi]
			, T.Item.value('@FechaMovimiento', 'DATE') AS [FechaMov] 
			, T.Item.value('@Monto', 'MONEY') AS [Monto]
			, T.Item.value('@Descripcion', 'VARCHAR(128)') AS [Descipcion]
			, T.Item.value('@Referencia', 'VARCHAR(128)') AS [Referencia]
		FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaOperacion")]/Movimiento/Movimiento')
		AS T(Item)
		INNER JOIN dbo.TipoMov M ON T.Item.value('@Nombre', 'VARCHAR(128)') = M.Nombre
		INNER JOIN dbo.TarjetaFis F ON T.Item.value('@TF', 'VARCHAR(128)') = F.Codigo
		WHERE ((EXISTS(SELECT 1 FROM dbo.TipoMov M WHERE M.Nombre = T.Item.value('@Nombre', 'VARCHAR(128)'))) AND
		(EXISTS (SELECT 1 FROM dbo.TarjetaFis F WHERE F.Codigo = T.Item.value('@TF', 'VARCHAR(128)'))))

		SELECT @hi = MAX(E.Sec) FROM @TableMovProces E

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion))
		BEGIN
			SELECT @LastLoId =EL.LastIdProccess
			, @CurrentEventLogId = EL.id
			FROM dbo.EventLog EL
			WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
			SELECT @lo = E.Sec+1
			FROM @TableMovProces E
			WHERE E.Sec=@LastLoId
		END
		
		ELSE
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
				VALUES (@idProceso, @InFechaOperacion, 'Proceso movimientos diarios', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END

		WHILE(@lo <= @hi)
		BEGIN 	
			SELECT @idTipoMov = M.idTipoMov
			, @idTarjFisi = M.idTarjFisi
			, @FechaMov = M.FechaMov
			, @Monto = M.Monto
			, @Descripcion = M.Descripcion
			, @Referencia = M.Referencia
			FROM @TableMovProces M 
			WHERE (@lo = M.Sec)

			SELECT @idCT = F.idCT
			, @EsMaestr = C.Es_Maestra
			FROM dbo.TarjetaFis F 
			INNER JOIN  dbo.Cuenta C ON C.id = F.idCT
			WHERE (@idTarjFisi = F.id)
			
			IF (@EsMaestr =0)
			BEGIN
				SELECT @idCTM = C.idCTM
				FROM dbo.CuentaAdi C
				WHERE C.idCT= @idCT
			END

			ELSE
			BEGIN
				SELECT @idCTM = M.id
				FROM dbo.CuentaMaest M
				WHERE M.idCT = @idCT
			END

			SELECT @SumaCred = dbo.FnSumaCreditos(@idTipoMov)
			, @SumaDeb = dbo.FNsumaDebitos(@idTipoMov)
			, @SumaPago = dbo.FnSumaPagos(@idTipoMov)
			, @SumaRetir = dbo.FnSumaRetiros(@idTipoMov)
			, @OperacionATM = dbo.FnSumaATM(@idTipoMov)
			, @OperacionVent = dbo.FnSumaVent(@idTipoMov)
			, @SumaCompras = dbo.FnSumaCompras(@idTipoMov)
			, @Monto = @Monto + dbo.FnCalcularRegla(@idCTM, @idTipoMov, @EsMaestr)
			
			--IF ((SELECT Nombre FROM dbo.TipoMov F WHERE F.id = @idTipoMov) ='Intereses Corrientes sobre Saldo')
			--BEGIN
			--	SELECT @Monto = C.Interes_AcuCorr
			--	FROM dbo.CuentaMaest C
			--	WHERE (C.id = @idCTM)
			--END

			--IF ((SELECT Nombre FROM dbo.TipoMov F WHERE F.id = @idTipoMov) = 'Intereses Moratorios Pago no Realizado')
			--BEGIN
			--	SELECT @Monto = C.Interes_AcuMora
			--	FROM dbo.CuentaMaest C
			--	WHERE (C.id = @idCTM)
			--END
			IF (@SumaDeb = 0)
			BEGIN
					SET @Monto = @Monto*-1 
			END

			SELECT @NuevoMonto = C.Saldo +@Monto
			FROM dbo.CuentaMaest C
			WHERE (C.id = @idCTM)

			SELECT @idEstadCuent= MAX(E.id)
				FROM dbo.EstadCuenta E
				WHERE(E.idCTM= @idCTM)

			SET @SumaMin = dbo.fnEnFechaMin(@InFechaOperacion, @idEstadCuent)
			INSERT INTO @TablaDatosEc (Sec, idEC, CantOpATM, CantOpVent, SumaPagosMin, CantPagoMes, SumaPagoMes, SumaCompra
			, CantCompras, SumaRetiros, CantRetiros, SumaTodosCred, CantTodosCred, SumaTodosDeb, CantTodosDeb)
			SELECT 
				F.Sec
				, @idEstadCuent
				, C.CantOpATM + @OperacionATM
				, C.CantOpVent +@OperacionVent
				, C.SumaPagosMin+ABS(@Monto)*@SumaDeb*@SumaMin 
				, C.CantPagoMes+@SumaDeb
				, C.SumaPagoMes+ABS(@Monto)*@SumaDeb
				, C.SumaCompra+ABS(@Monto)*@SumaCompras
				, C.CantCompras+@SumaCompras
				, C.SumaRetiros+ABS(@Monto)*@SumaRetir
				, C.CantRetiros+@SumaRetir
				, C.SumaTodosCred + ABS(@Monto)*@SumaCred
				, C.CantTodosCred + @SumaCred
				, C.SumaTodosDeb +ABS(@Monto)*@SumaDeb
				, C.CantTodosDeb +@SumaDeb
			FROM dbo.EstadCuenta C 
			INNER JOIN @TableMovProces F ON F.Sec = @lo
			WHERE C.id = @idEstadCuent
			
			
			IF(@EsMaestr = 0)
			BEGIN
				SELECT @idSubEstadCuent = MAX(E.id)
						FROM dbo.SubEstadCuent E
						INNER JOIN dbo.CuentaAdi A ON A.idCT = @idCT
						WHERE(A.id= E.idCTA)

				INSERT INTO @TablaSubEcCalc (SEC, idSubEC, CantOpATM, CantOpVent, CantCompras, SumaCompra, SumaRetiros, 
				CantRetiros,SumaTodosCred, SumaTodosDeb)
				SELECT 
					F.Sec
					, @idSubEstadCuent
					, C.CantOpATM + @OperacionATM
					, C.CantOpVent + @OperacionVent
					, C.CantCompra+@SumaCompras
					, C.SumaCompra+Abs(@Monto)* @SumaCompras 
					, C.SumaRetiros+Abs(@Monto)*@SumaRetir
					, C.CantRetiros+ @SumaRetir
					, C.SumaTodosCred+ABS(@Monto)*@SumaCred
					, C.SumaTodosDeb+ABS(@Monto)*@SumaDeb
					FROM dbo.SubEstadCuent C 
					INNER JOIN @TableMovProces F ON F.Sec = @lo 
					WHERE C.id = @idSubEstadCuent
				
			END

			BEGIN TRANSACTION soloUnoProcesarMov

				IF(dbo.FNTarjetaVencida(@idTarjFisi, @InFechaOperacion) = 0)
				BEGIN
					INSERT INTO dbo.Movimiento(idTipoMov, idTF, Descripcion, Fecha, Monto, Referencia, Nuevo_Saldo)
					VALUES(@idTipoMov, @idTarjFisi,@Descripcion, @FechaMov, @Monto, @Referencia, @NuevoMonto)
				
					UPDATE dbo.EstadCuenta
					SET Saldo = @NuevoMonto
					, CantOpATM = C.CantOpATM 
					, CantOpVent= C.CantOpVent 
					, SumaPagosMin = C.SumaPagosMin
					, CantPagoMes = C.CantPagoMes
					, SumaPagoMes = C.SumaPagoMes
					, SumaCompra = C.SumaCompra
					, CantCompras = C.CantCompras
					, SumaRetiros = C.SumaRetiros
					, CantRetiros = C.CantRetiros
					, SumaTodosCred = C.SumaTodosCred 
					, CantTodosCred = C.CantTodosCred 
					, SumaTodosDeb = C.SumaTodosDeb 
					, CantTodosDeb = C.CantTodosDeb 
					FROM @TablaDatosEc C
					WHERE (@idEstadCuent = id) AND (C.Sec = @lo)
				
					IF(@EsMaestr = 0)
					BEGIN
					
						UPDATE dbo.SubEstadCuent 
						SET CantOpATM = C.CantOpATM 
						, CantOpVent = C.CantOpVent 
						, CantCompra = C.CantCompras
						, SumaCompra = C.SumaCompra
						, SumaRetiros = C.SumaRetiros
						, CantRetiros = C.CantRetiros
						, SumaTodosCred = C.SumaTodosCred
						, SumaTodosDeb = C.SumaTodosDeb
						FROM @TablaSubEcCalc C
						WHERE (@idSubEstadCuent = id) AND (C.SEC = @lo)
					END
				
					UPDATE dbo.CuentaMaest
					SET Saldo = @NuevoMonto 
					WHERE (id = @idCTM)

				END

				ELSE
				BEGIN
					INSERT INTO dbo.MovSospechoso(idTipoMov, idTarjetaFis, Fecha, Descripcion, Monto, Referencia)
					VALUES(@idTipoMov, @idTarjFisi, @FechaMov, @Descripcion, @Monto, @Referencia)
				END

				UPDATE dbo.EventLog
					SET LastIdProccess = @lo
					WHERE(id = @CurrentEventLogId)
				
			COMMIT TRANSACTION soloUnoProcesarMov
			
			SET @lo += 1 
		
		END
	
	END TRY
	
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION soloUnoProcesarMov
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
DECLARE @Result INT
EXEC dbo.ProcesamientoMovimientos '2023-05-25', @Result OUTPUT