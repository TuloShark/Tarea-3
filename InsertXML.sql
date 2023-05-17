USE [Tarea_3]
GO

/****** Object:  StoredProcedure [dbo].[InsertXML]    Script Date: 17/5/2023 10:24:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertXML]
AS
BEGIN
	DELETE FROM [dbo].[TipoDocIdent] -- Se borran los datos de las tablas para evitar repetidos
	DELETE FROM [dbo].[TipoCuentaTM]
	DELETE FROM [dbo].[ReglaNeg]
	DELETE FROM [dbo].[TipoReglaNeg]
	DELETE FROM [dbo].[MotivoInvTarjeta]
	DELETE FROM [dbo].[TipoMov]
	DELETE FROM [dbo].[Administradores]
	DELETE FROM [dbo].[TMTI]


	DBCC CHECKIDENT ('TipoDocIdent', RESEED,0) -- Se declaran los valores iniciales de los id de las tablas en 0
	DBCC CHECKIDENT ('TipoCuentaTM', RESEED,0)
	DBCC CHECKIDENT ('TipoReglaNeg', RESEED,0)
	DBCC CHECKIDENT ('ReglaNeg', RESEED,0)
	DBCC CHECKIDENT ('MotivoInvTarjeta', RESEED,0)
	DBCC CHECKIDENT ('TipoMov', RESEED,0)
	DBCC CHECKIDENT ('Administradores', RESEED,0)
	DBCC CHECKIDENT ('TMTI', RESEED,0)

	DECLARE @xmlData XML -- Se declara la variable XML

	SET @xmlData = 
		( -- Se define la variable XML, se utiliza la dirección del archivo
		SELECT *
		FROM OPENROWSET(BULK 'C:\Aaron\Base de datos\Tarea3\Catalogos.xml', SINGLE_BLOB) -- En este caso se usa la ruta de un S3 BUCKET
		AS xmlData -- Se guarda en una variable para futuras lecturas
		);

	INSERT INTO [dbo].[TipoDocIdent]
	SELECT  
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre],
		T.Item.value('@Formato', 'VARCHAR(128)') AS [Formato]
	FROM @xmlData.nodes('root/TDI/TDI') -- Ruta de Usuario
	AS T(Item)

	INSERT INTO [dbo].[TipoCuentaTM]
	SELECT  
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre]
	FROM @xmlData.nodes('root/TCTM/TCTM')
	AS T(Item)

	INSERT INTO [dbo].[TipoReglaNeg]
	SELECT  
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre],
		T.Item.value('@tipo', 'VARCHAR(128)') AS [Tipo]
	FROM @xmlData.nodes('root/TRN/TRN')
	AS T(Item)

	INSERT INTO [dbo].[ReglaNeg]
	SELECT
		(SELECT id FROM [dbo].[TipoReglaNeg] WHERE [Nombre] = T.Item.value('@TipoRN', 'VARCHAR(128)')) AS [idTipoReglaNeg],
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre],
		T.Item.value('@TCTM', 'VARCHAR(128)') AS [TCTM],
		T.Item.value('@TipoRN', 'VARCHAR(128)') AS [TipoRN],
		T.Item.value('@Valor', 'VARCHAR(128)') AS [Valor]
	FROM @xmlData.nodes('root/RN/RN')
	AS T(Item)

		INSERT INTO [dbo].[MotivoInvTarjeta]
	SELECT  
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre]
	FROM @xmlData.nodes('root/MIT/MIT')
	AS T(Item)

	INSERT INTO [dbo].[TipoMov]
	SELECT  
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre],
		T.Item.value('@Accion', 'VARCHAR(128)') AS [Accion],
		T.Item.value('@Acumula_Operacion_ATM', 'VARCHAR(128)') AS [Acumula_Operacion_ATM],
		T.Item.value('@Acumula_Operacion_Ventana', 'VARCHAR(128)') AS [Acumula_Operacion_Ventana]
	FROM @xmlData.nodes('root/TM/TM')
	AS T(Item)

	INSERT INTO [dbo].[Administradores] -- Se inserta a la tabla Usuario
	SELECT  
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [UserName],
		T.Item.value('@Password', 'VARCHAR(128)') AS [Password]
	FROM @xmlData.nodes('root/UA/Usuario') -- Ruta de Usuario
	AS T(Item)

	INSERT INTO [dbo].[TMTI]
	SELECT  
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre],
		T.Item.value('@Accion', 'VARCHAR(128)') AS [Accion]
	FROM @xmlData.nodes('root/TMTI/TMTI')
	AS T(Item)
/*
	SELECT
		(SELECT id FROM [dbo].[ClaseArticulo] WHERE [Nombre] =
		T.Item.value('@ClasesdeArticulo', 'VARCHAR(128)')) AS [idClaseArticulo],
		T.Item.value('@Nombre', 'VARCHAR(128)') AS [Nombre],
		T.Item.value('@precio', 'money') AS [Precio]
	FROM @xmlData.nodes('root/Articulos/Articulo')
	AS T(Item)
*/
END
GO


