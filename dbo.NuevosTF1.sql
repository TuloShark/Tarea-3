USE [Tarea_3]
GO
/****** Object:  StoredProcedure [dbo].[nuevosTF]    Script Date: 27/5/2023 12:30:55 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[nuevosTF]
(
	@InFechaOperacion DATE
	, @OutResult INT OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRY
		
		DECLARE @lo INT --Declaración de variables a utilizar
		, @hi INT
		, @idProceso INT = 9
		, @CurrentEventLogId INT
		, @LastLoId INT
		, @Codigo  VARCHAR(128)
		, @idCT INT
		, @FechaVencimiento DATE
		, @CCV VARCHAR(128);

		DECLARE @xmlData XML -- Se declara la variable XML
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB) --  Se busca el archivo local
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);
		DECLARE @TablaTF TABLE --Declaración de tablas para cargar datos xml
		(
			Sec INT IDENTITY(1,1)
			, Codigo VARCHAR(128)
			, idCT INT 
			, FechaVenc DATE
			, CCV VARCHAR(32)
		);
		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion) 
									AND (LastIdProccess=LastIdToBeProcessed)) --Si el proceso ya se cargo
		BEGIN
			SET @OutResult = 50024
		END

		INSERT INTO @TablaTF(Codigo, idCT, FechaVenc, CCV) --Se cargan los datos del xml en tabla
		SELECT 
			T.Item.value('@Codigo', 'VARCHAR(128)') AS [Codigo]
			, C.id AS [idCT]
			, CONVERT(DATE, CONVERT(VARCHAR , DAY(GETDATE()))+'/'+
			T.Item.value('@FechaVencimiento', 'VARCHAR(32)'), 105) AS [FechaVenc]
			, T.Item.value('@CCV', 'VARCHAR(32)') AS [CCV]
		FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaOperacion")]/NTF/NTF')
		AS T(Item)
		INNER JOIN dbo.Cuenta C ON C.Codigo = T.Item.value('@TCAsociada', 'VARCHAR(128)')  
		WHERE (EXISTS(SELECT 1 FROM dbo.Cuenta C WHERE C.Codigo = T.Item.value('@TCAsociada', 'VARCHAR(128)')))
		
		SELECT @hi = MAX(E.Sec) FROM @TablaTF E --Se obtienen el ultimo elemento a procesar 

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion)) --Si no se completo el proceso
		BEGIN
			SELECT @LastLoId =EL.LastIdProccess
			, @CurrentEventLogId = EL.id
			FROM dbo.EventLog EL
			WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
			SELECT @lo = E.Sec+1
			FROM @TablaTF E
			WHERE E.Sec=@LastLoId
		END
		
		ELSE  --Si se corre por primera vez
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
				VALUES (@idProceso, @InFechaOperacion, 'Proceso creación nuevos TF', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END
		WHILE(@lo<= @hi)
		BEGIN
			SELECT @Codigo = E.Codigo
				, @idCT = E.idCT
				, @FechaVencimiento = E.FechaVenc
				, @CCV = E.CCV
			FROM @TablaTF E
			WHERE (@lo = E.Sec) --Se obtiene los datos del elemento actual a procesar de la tabla
			
			BEGIN TRANSACTION soloUnoNuevTarjFisic

				INSERT INTO dbo.TarjetaFis(Codigo, idCT, Fecha_Venci, CVV, Fecha_Emi, Fecha_Inva) 
				VALUES(@Codigo
				, @idCT
				, @FechaVencimiento
				, @CCV
				, @InFechaOperacion
				, @FechaVencimiento
				) --Se inserta los elementos en tabla fisica
				
				UPDATE dbo.EventLog
				SET LastIdProccess = @lo
				WHERE id = @CurrentEventLogId --Se actualiza el ultimo elemento procesado

			COMMIT TRANSACTION soloUnoNuevTarjFisic
			SET @lo = @lo+1 --Pasamos al siguiente elemento a procesar
		END 

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