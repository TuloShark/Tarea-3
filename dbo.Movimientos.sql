CREATE PROCEDURE xmlPrueba
(
	@InFechaActual DATE
)
AS BEGIN
	DECLARE @xmlData XML -- Se declara la variable XML
		SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
			SELECT *
			FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\XMLBD2_OperacionesFinal.xml', SINGLE_BLOB) -- En este caso se usa la ruta de un S3 BUCKET
			AS xmlData -- Se guarda en una variable para futuras lecturas
		);

	DECLARE @TablaMov TABLE
	(
		SEC INT IDENTITY(1,1) 
		, idTipoMov INT
		, idTarFis INT
		, FechaMov DATE
		, Monto INT
		, Descrption VARCHAR(128)
		, Referencia VARCHAR(16)
	);
	DECLARE @TablaTh TABLE  
	(
		Sec INT IDENTITY (1,1)
		, idCuentMaest INT
		, idTarjFisica INT
		, debito FLOAT
		, Credito FLOAT
		, CantidadATM INT
		, CantidadVentani INT
		, NuevoSaldo FLOAT
	);
	INSERT INTO @TablaMov (idTipoMov, idTarFis, FechaMov, Monto, Descrption, Referencia)
	SELECT 
		TM.id
		,TF.id
		,T.Item.value('@FechaMovimiento', 'DATE') AS Fecha
		, T.Item.value('@Monto', 'FLOAT') AS Monto
		, T.Item.value('@Descripcion', 'VARCHAR(128)') AS Descripcion
		, T.Item.value('@Referencia', 'VARCHAR(16)') AS Referencia
	FROM @xmlData.nodes('root/fechaOperacion[@Fecha = sql:variable("@InFechaActual")]/Movimiento/Movimiento')
	AS T(Item)
	INNER JOIN dbo.TarjetaFis TF ON T.Item.value('@TF', 'VARCHAR(126)') = TF.Codigo
	INNER JOIN dbo.TipoMov TM ON T.Item.value('@Nombre', 'VARCHAR(126)') = TM.Nombre
	
	INSERT INTO @TablaTh (idCuentMaest, idTarjFisica ,NuevoSaldo)
	SELECT
		 C.idCuentMae
		, C.idTarj
		, S.Saldo
	FROM dbo.Vista_TarjFis_CTA C
	INNER JOIN dbo.CuentaMaest S ON C.idCuentMae = S.id
	WHERE EXISTS(SELECT 1 FROM @TablaMov TM WHERE TM.idTarFis = C.idTarj)
	
	UPDATE @TablaTh
		SET NuevoSaldo = (SELECT SUM(Monto) FROM @TablaMov TM WHERE 
		EXISTS(SELECT 1 FROM dbo.vista_MovDebito M WHERE M.id = TM.idTipoMov) AND TM.idTarFis= idTarFis )
	FROM @TablaMov

	UPDATE @TablaTh
		SET CantidadATM = (SELECT COUNT(*) FROM @TablaMov WHERE )
		
END
