ALTER PROCEDURE dbo.llenarRN
AS
BEGIN
BEGIN TRY
SET NOCOUNT ON
	DECLARE @lo INT
	, @hi INT
	, @idRegla INT
	, @idReglaxTC INT
	, @Nombre VARCHAR(128)
	, @idTipoCTM INT
	, @valor VARCHAR(128)
	, @idTipoRN INT
	, @Tipo VARCHAR(32)

	DECLARE @xmlData XML -- Se declara la variable XML
		
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_Catalogos.xml', SINGLE_BLOB) -- En este caso se usa la ruta de un S3 BUCKET
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);

		DECLARE @TablaRn TABLE -- Tablas para cargar los datos del xml
		(
			Sec INT IDENTITY(1,1)  
			, Nombre VARCHAR(128)
			, TipoCTM INT
			, TipoRN INT
			, Valor VARCHAR(128)
		);

		INSERT INTO @TablaRn (Nombre, TipoCTM, TipoRN, Valor)
		SELECT
			T.Item.value('@Nombre', 'VARCHAR(128)')
			, C.id
			, R.id
			, T.Item.value('@Valor', 'VARCHAR(128)')
		FROM @xmlData.nodes('root/RN/RN')
		AS T(Item)
		INNER JOIN dbo.TipoCuentaTM C ON T.Item.value('@TCTM', 'VARCHAR(64)') = C.Nombre
		INNER JOIN dbo.TipoReglaNeg R ON T.Item.value('@TipoRN', 'VARCHAR(64)') = R.Nombre
		
		SELECT @hi = MAX(Sec) FROM @TablaRn;
		SET @lo = 1;

		WHILE(@lo <= @hi)
		BEGIN

			SELECT
				@Nombre = T.Nombre
				, @idTipoCTM =T.TipoCTM
				,@idTipoRN = T.TipoRN
				, @valor = T.Valor
			FROM @TablaRn T WHERE (@lo = Sec)
			BEGIN TRANSACTION llenarRNSoloUNO
			
			IF (NOT EXISTS(SELECT 1 FROM dbo.ReglaNeg WHERE Nombre = @Nombre))
			BEGIN
				INSERT INTO dbo.ReglaNeg(idTipoReglaNeg, Nombre)
				VALUES(@idTipoRN, @Nombre)
			END

			SET @idRegla = (SELECT id FROM dbo.ReglaNeg WHERE Nombre=@Nombre);

			INSERT INTO dbo.reglaXTipoCuent(idReglaNeg, idTipoCTM)
			VALUES(@idRegla, @idTipoCTM)
			
			SET @idReglaxTC =SCOPE_IDENTITY()

			SET @Tipo = (SELECT TP.Nombre FROM dbo.TipoReglaNeg TP WHERE id=@idTipoRN) 
			
			IF (@Tipo = 'Porcentaje')
			BEGIN
				INSERT INTO [dbo].[reglaXtcPorct]([idReglaXTc], valor)
				VALUES(@idReglaxTC, CAST(@valor AS REAL))
			END
			
			ElSE IF (@Tipo = 'Cantidad de Dias')
			BEGIN
				INSERT INTO dbo.reglaXtcQdias(idReglaXTc, valor)
				VALUES(@idReglaxTC, CAST(@valor AS INT));
			END
			
			ELSE IF (@Tipo = 'Cantidad de Operaciones')
			BEGIN
				INSERT INTO dbo.reglaXtcQp(idReglaXTc, valor)
				VALUES(@idReglaxTC, CAST(@valor AS INT))
			END

			ELSE IF (@Tipo = 'Monto Monetario')
			BEGIN
				INSERT INTO dbo.reglaXtcMontMonet(idReglaXTc, valor)
				VALUES(@idReglaxTC, CAST(REPLACE(@valor, '.', '') AS MONEY))
			END
			COMMIT TRANSACTION llenarRNSoloUNO
			SET @lo= @lo+1
			
		END
		
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0
	BEGIN
		ROLLBACK TRANSACTION llenarRNSoloUNO
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
END CATCH
SET NOCOUNT OFF
END
EXEC dbo.llenarRN
