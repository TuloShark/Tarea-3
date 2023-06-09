USE [Tarea_3]
GO
/****** Object:  StoredProcedure [dbo].[nuevosCTM]    Script Date: 27/5/2023 11:57:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[nuevosCTM]
(
	@InFechaOperacion DATE
	, @OutResult INT OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRY
		
		DECLARE @lo INT -- Declaración de variables a utilizar
		, @hi INT
		, @idProceso INT = 2
		, @CurrentEventLogId INT
		, @LastLoId INT
		, @idCuenMaestr INT
		, @Codigo  INT
		, @idTipoCTM INT
		, @LimiteCredito MONEY
		, @idTarjeHabien INT;

		DECLARE @xmlData XML -- Se declara la variable XML
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB) -- Se busca el archivo local
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);
		DECLARE @TablaCTM TABLE --Declaración de variable tabla
		(
			Sec INT IDENTITY(1,1)
			, Codigo INT
			, idTipoCTM INT
			, LimiteCredito MONEY
			, idTarjeHabien INT
		)
		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion) 
									AND (LastIdProccess=LastIdToBeProcessed))
		BEGIN;
			SET @OutResult = 50022
		END;
		INSERT INTO @TablaCTM(Codigo, idTipoCTM, LimiteCredito, idTarjeHabien)
		SELECT 
			T.Item.value('@Codigo', 'INT')
			, TC.id
			, T.Item.value('@LimiteCredito', 'MONEY')
			, TH.id
		FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaOperacion")]/NTCM/NTCM')
		AS T(Item)
		INNER JOIN dbo.TipoCuentaTM TC ON T.Item.value('@TipoCTM', 'VARCHAR(128)') = TC.Nombre
		INNER JOIN dbo.TarjetaHabiente TH ON T.Item.value('@TH', 'VARCHAR(128)') = TH.ValorDocIdent
		WHERE (EXISTS(SELECT 1 FROM dbo.TarjetaHabiente TJ 
		WHERE T.Item.value('@TH', 'VARCHAR(128)') = TJ.ValorDocIdent)) AND
		(EXISTS(SELECT 1 FROM dbo.TipoCuentaTM TP WHERE T.Item.value('@TipoCTM', 'VARCHAR(128)') = TP.Nombre))

		SELECT @hi = MAX(E.Sec) FROM @TablaCTM E --Se obtiene el id mayor a procesar

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion)) --Si se proceso pero no se completo
		BEGIN
			SELECT @LastLoId =EL.LastIdProccess
			, @CurrentEventLogId = EL.id
			FROM dbo.EventLog EL
			WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
			SELECT @lo = E.Sec+1
			FROM @TablaCTM E
			WHERE E.Sec=@LastLoId
		END

		ELSE --Si recorre por primera vez
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed) -- Inserta en eventLog
				VALUES (@idProceso, @InFechaOperacion, 'Proceso creación nuevos CTM', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END
		
		WHILE(@lo <= @hi)
		BEGIN

				SELECT @Codigo= C.Codigo
					, @idTipoCTM = C.idTipoCTM
					, @LimiteCredito =C.LimiteCredito
					, @idTarjeHabien = C.idTarjeHabien
				FROM @TablaCTM C WHERE C.Sec = @lo --Se obtienen los valores cargados 
			
			BEGIN TRANSACTION creacionCTMsolouno

				INSERT INTO dbo.Cuenta(Codigo, Es_Maestra, Fecha_Creacion, idTarjetaHabiente) --Se inserta los valores en cuenta
				VALUES(@Codigo
				, 1
				, @InFechaOperacion
				, @idTarjeHabien
				);
				
				SET @idCuenMaestr = SCOPE_IDENTITY()

				INSERT INTO dbo.CuentaMaest(Saldo, Interes_AcuCorr, Interes_AcuMora, idCT, idTipoCTM, LimiteCred)
				VALUES(0, 
				0
				, 0
				, @idCuenMaestr
				, @idTipoCTM
				, @LimiteCredito
				);
				
				UPDATE dbo.EventLog
				SET LastIdProccess = @lo
				WHERE id = @CurrentEventLogId;

			COMMIT TRANSACTION creacionCTMsolouno
			
			SET @lo = @lo+1;
		END;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION creacionCTMsolouno
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
			SET @OutResult =500205
	END CATCH
	SET NOCOUNT OFF
END