CREATE TRIGGER dbo.NuevasSubEcCTA ON dbo.CuentaAdi
AFTER INSERT
AS
BEGIN
	
	SET NOCOUNT ON
	
	BEGIN TRY

		DECLARE @idCTA INT
		, @FechaCreacion DATE

		SELECT @idCTA = F.id 
			, @FechaCreacion= C.Fecha_Creacion
		FROM inserted F
		INNER JOIN dbo.Cuenta C ON F.idCT= C.id
		
		INSERT INTO dbo.SubEstadCuent(idCTA, Fecha,CantCompra, CantOpATM, CantOpVent, CantRetiros, SumaCompra,
		SumaTodosCred, SumaTodosDeb, SumaRetiros)
		VALUES(@idCTA, @FechaCreacion, 0, 0, 0, 0, 0, 0, 0, 0) 
			
	END TRY
	BEGIN CATCH
		
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