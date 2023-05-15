CREATE TABLE SubEstadCuent
(
	id INT IDENTITY(1,1) PRIMARY KEY
	, CantOpATM INT
	, CantOpVent INT
	, SumaCompra MONEY
	, CantCompra INT
	, SumaRetiros MONEY
	, CantRetiros INT
	, SumaTodosCred MONEY
	, SumaTodosDeb MONEY
)