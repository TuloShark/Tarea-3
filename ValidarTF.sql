USE [Tarea_3]
GO

/****** Object:  StoredProcedure [dbo].[validarTF]    Script Date: 17/5/2023 10:24:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[validarTF]
(
	@InFechaOperacion DATE
)
AS
	DECLARE
		@FechaVencimiento VARCHAR(128)
		, @CodigoTCM VARCHAR(128)
		, @CodigoTCA VARCHAR(128)
		, @TipoCTM VARCHAR(128)
		, @Monto MONEY
		
		, @CurrentEventLogId INT
		, @LastLoId INT
		, @idProceso INT = 5
		, @hi INT
		, @lo INT

	DECLARE @xmlData XML
	
		SET @xmlData = 
		(
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB)
			AS xmlData
		);

		DECLARE @TablaTF TABLE 
		(
			Sec INT IDENTITY(1,1)
			, Codigo VARCHAR(128)
			, CodigoTCM VARCHAR(128)
			, TipoCTM VARCHAR(128)	
			, TCAsociada INT
			, FechaVencimiento VARCHAR(128)
			, CCV INT
			, Vencida BIT
		);

BEGIN

	INSERT INTO @TablaTF(Codigo, TCAsociada, FechaVencimiento, CCV, Vencida)
		SELECT 
			T.Item.value('@Codigo', 'VARCHAR(128)')
			, T.Item.value('@TCAsociada', 'INT') 
			, T.Item.value('@FechaVencimiento', 'VARCHAR(128)')
			, T.Item.value('@CCV', 'INT')
			, Vencida = 0
		FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaOperacion")]/NTF/NTF')
		AS T(Item)


	SELECT @hi = MAX(E.Sec) FROM @TablaTF E
	SELECT @lo = MIN(E.Sec) FROM @TablaTF E

	WHILE(@lo <= @hi)
		BEGIN
			SET @CodigoTCA = (SELECT TCAsociada FROM @TablaTF WHERE Sec = @lo)
			SET @CodigoTCM = (SELECT CodigoTCM FROM ProvisionalTCA WHERE [CodigoTCA] = @CodigoTCA)
			SET @TipoCTM = (SELECT TipoCTM FROM ProvisionalCTM WHERE Codigo = @CodigoTCM)
				UPDATE @TablaTF
				SET	
					CodigoTCM = @CodigoTCM
					, TipoCTM = @TipoCTM
				WHERE Sec = @lo
				IF (@InFechaOperacion >= @FechaVencimiento)
					UPDATE @TablaTF
					SET Vencida = 1
					WHERE Sec = @lo

					UPDATE dbo.EventLog
					SET LastIdProccess = @lo
					WHERE IdEventType = @idProceso
			SET @lo = @lo+1
		END
	SELECT * FROM @TablaTF
END
GO


