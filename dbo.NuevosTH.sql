USE [Tarea_3]
GO

/****** Object:  StoredProcedure [dbo].[NuevoTarHabien]    Script Date: 10/5/2023 13:53:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NuevoTarHabien]
(
	@InFechaOperacion DATE
	, @OutResult INT OUTPUT
)
AS 
BEGIN
	SET NOCOUNT ON
BEGIN TRY
	DECLARE @hi INT
	, @lo INT
	, @idProceso INT = 1
	, @CurrentEventLogId INT
	, @LastLoId INT
	, @Nombre VARCHAR(128)
	, @idTipIdent INT
	, @valorIdenti VARCHAR(32)
	, @Usuario VARCHAR(32)
	, @Password VARCHAR(32)

	DECLARE @xmlData XML -- Se declara la variable XML
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB) -- En este caso se usa la ruta de un S3 BUCKET
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);
	
	DECLARE @NewTarha TABLE -- Tabla para procesar las nuevas cuentas 
	(
		Sec INT IDENTITY(1,1)
		, Nombre VARCHAR(128)
		, idTipoIdent INT
		, valorIdent VARCHAR(32)
		, Usuario VARCHAR(32)
		, Password VARCHAR(32)
	)

	IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion) 
									AND (LastIdProccess=LastIdToBeProcessed)) -- Se comprueba que la operacion en ese mismo dia no se ejecuto dos veces
		BEGIN
			--SET @OutResult = 50021 -- Ya se ejecuto, codigo de error
			RETURN
		END
	
	INSERT INTO @NewTarha(Nombre, idTipoIdent, valorIdent, Usuario, Password)
	SELECT 
		T.Item.value('@Nombre', 'VARCHAR(128)') AS Nombre
		, VI.id
		, T.Item.value('@Valor_Doc_Identidad', 'VARCHAR(32)')
		, T.Item.value('@NombreUsuario', 'VARCHAR(32)')
		, T.Item.value('@Password', 'VARCHAR(32)')
	FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaOperacion")]/TH/TH')
	AS T(Item)
	INNER JOIN dbo.TipoDocIdent VI ON T.Item.value('@Tipo_Doc_Identidad', 'VARCHAR(16)') = VI.Nombre
	WHERE EXISTS(SELECT 1 FROM dbo.TipoDocIdent WHERE T.Item.value('@Tipo_Doc_Identidad', 'VARCHAR(16)')= Nombre)
	
	SELECT @hi= MAX(E.Sec) FROM @NewTarha E
	
	IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion))
		BEGIN
			SELECT @LastLoId = EL.LastIdProccess
			, @CurrentEventLogId = EL.id
			FROM dbo.EventLog EL
			WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
			SELECT @lo = E.Sec+1
			FROM @NewTarha E
			WHERE E.Sec=@LastLoId
		END

	ELSE
		BEGIN
			SET @lo =1
			INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
			VALUES (@idProceso, @InFechaOperacion, 'Proceso creación nuevos TH', 0, @hi)
			SET @CurrentEventLogId = SCOPE_IDENTITY()
		END 

	WHILE(@lo<=@hi)
	BEGIN;
		SELECT @Nombre = T.Nombre
		, @idTipIdent= T.idTipoIdent
		, @valorIdenti = T.valorIdent
		, @Usuario = T.Usuario
		, @Password = T.Password
		FROM @NewTarha T 
		WHERE (T.Sec =@lo);

		BEGIN TRANSACTION creacionTHSoloUno
			INSERT INTO dbo.TarjetaHabiente (Nombre, idTipoDocIdent, ValorDocIdent, NombreUsuario, Password)
			VALUES(@Nombre
			, @idTipIdent
			, @valorIdenti
			, @Usuario
			, @Password
			);
			
			UPDATE dbo.EventLog
			SET LastIdProccess = @lo
			WHERE id = @CurrentEventLogId;
		
		COMMIT TRANSACTION creacionTHSoloUno

		SET @lo = @lo+1;
	END
END TRY

BEGIN CATCH

	IF @@TRANCOUNT > 0
	BEGIN
		ROLLBACK TRANSACTION creacionTHSoloUno
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
		--SET @OutResult =500204
	
END CATCH
SET NOCOUNT OFF

END 
GO
DECLARE @Result int
EXEC dbo.NuevoTarHabien '2023-05-05', @Result

