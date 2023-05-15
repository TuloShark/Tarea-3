CREATE PROCEDURE dbo.ProcesamientoMovimientos
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
		, @idProceso INT = 3
		, @CurrentEventLogId INT
		, @LastLoId INT

		DECLARE @xmlData XML -- Se declara la variable XML
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB) -- Ruta del archivo.
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);
		DECLARE @TableMovProces TABLE
		(
			Sec INT IDENTITY(1,1)
			, idTipoMov INT
			, idTarjFisi INT 
			, FechaMov DATE
			, Monto MONEY
			, Descripcion VARCHAR(128)
			, Referencia VARCHAR(128)
		)

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion) 
									AND (LastIdProccess=LastIdToBeProcessed))
		BEGIN
			SET @OutResult = 50022
		END

		INSERT INTO @TableMovProces (idTipoMov, idTarjFisi, FechaMov, Monto, Descripcion, Referencia)
		SELECT 
			M.id AS [idTipoMov]
			, F.id AS [idTarjFisi]
			, T.Item.value('@FechaMovimiento', 'DATE') AS [FechaMov] 
			, T.Item.value('@Monto', 'MONEY') AS [Monto]
			, T.Item.value('@Descripcion', 'VARCHAR(128)') AS [Descipcion]
			, T.Item.value('@Referencia', 'VARCHAR(128)') AS [Referencia]
		FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaOperacion")]/Movimiento/')
		AS T(Item)
		INNER JOIN dbo.TipoMov M ON T.Item.value('@Nombre', 'VARCHAR(128)') = M.Nombre
		INNER JOIN dbo.TarjetaFis F ON T.Item.value('@TF', 'VARCHAR(128)') = F.Codigo

		IF EXISTS(SELECT 1 FROM dbo.EventLog WHERE (IdEventType= @idProceso) AND (EvenDate= @InFechaOperacion))
		BEGIN
			SELECT @LastLoId =EL.LastIdProccess
			, @CurrentEventLogId = EL.id
			FROM dbo.EventLog EL
			WHERE (IdEventType=@idProceso) AND (EvenDate= @InFechaOperacion)
		
			SELECT @lo = E.Sec+1
			FROM @TablaCTM E
			WHERE E.Sec=@LastLoId
		END
		
		ELSE
			BEGIN
				SET @lo = 1
				INSERT INTO dbo.EventLog(idEventType, EvenDate, Description, LastIdProccess, LastIdToBeProcessed)
				VALUES (@idProceso, @InFechaOperacion, 'Proceso creación nuevos CTM', 0, @hi)
				SET @CurrentEventLogId = SCOPE_IDENTITY()
			END

		
		




	END TRY
	
	BEGIN CATCH

	END CATCH

	SET NOCOUNT OFF
END 