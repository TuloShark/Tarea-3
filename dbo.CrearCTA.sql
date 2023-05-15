CREATE PROCEDURE dbo.crearCTA
(
	@InFechaOperacion DATE 
	, @OutResult INT OUTPUT
)
AS 
BEGIN
BEGIN TRY
	DECLARE 
		  @lo INT
		, @hi INT
		, @idProceso INT = 3
		, @CurrentEventLogId INT
		, @LastLoId INT
		, @CodigoCTA INT
		, @idCTM INT
		, @idTH INT
		, @idCT INT 

	DECLARE @xmlData XML -- Se declara la variable XML
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB) -- En este caso se usa la ruta de un S3 BUCKET
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);
	DECLARE @TablaCTA TABLE
	(
		Sec INT IDENTITY(1,1)
		, codigoCTA INT
		, idCTM INT
		, idTarjHabien INT
	);

	IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion) 
								AND (LastIdProccess=LastIdToBeProcessed))
		BEGIN
			SET @OutResult = 50023
		END

	INSERT INTO @TablaCTA(codigoCTA, idCTM, idTarjHabien)
		SELECT 
			T.Item.value('@CodigoTCA', 'INT')
			, TCM.idCTM
			, TH.id
		FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaOperacion")]/NTCM/NTCM')
		AS T(Item)
		INNER JOIN dbo.TarjetaHabiente TH ON T.Item.value('@TH', 'VARCHAR()') = TH.ValorDocIdent
		INNER JOIN dbo.vistaCTM TCM ON TCM.Codigo = T.Item.value('@CodigoTCM', 'VARCHAR(128)')

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion))
		BEGIN
			SELECT @LastLoId = EL.LastIdProccess
			, @CurrentEventLogId = EL.id
			FROM dbo.EventLog EL
			WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
			SELECT @lo = E.Sec+1
			FROM @TablaCTA E
			WHERE E.Sec=@LastLoId
		END

		ELSE
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
				VALUES (@idProceso, @InFechaOperacion, 'Proceso creación nuevos CTA', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END
		WHILE(@lo<=@hi)
		BEGIN
		
			SELECT @CodigoCTA= C.codigoCTA
				, @idCTM = C.idCTM
				, @idTH = C.idTarjHabien
			FROM @TablaCTA C WHERE(@lo= C.Sec)

			BEGIN TRANSACTION creacionCTASoloUno
				INSERT INTO dbo.Cuenta(Codigo, Es_Maestra, Fecha_Creacion, idTarjetaHabiente)
				VALUES(@CodigoCTA, 0, @InFechaOperacion, @idTH)

				SET @idCT = SCOPE_IDENTITY();

				INSERT INTO dbo.CuentaAdi(idCT,	idCTM)
				VALUES(@idCT, @idCTM)

				UPDATE dbo.EventLog
				SET LastIdProccess = @lo
				WHERE id = @CurrentEventLogId;

			COMMIT TRANSACTION creacionCTASoloUno

			SET @lo = @lo+1
		END 
END TRY
BEGIN CATCH
	
	IF @@TRANCOUNT > 0
	BEGIN
		ROLLBACK TRANSACTION creacionCTASoloUno
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
		SET @OutResult =500204

END CATCH
END