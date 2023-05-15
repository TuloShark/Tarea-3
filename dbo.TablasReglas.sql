CREATE TABLE dbo.reglaXTipoCuent
(
	id INT PRIMARY KEY IDENTITY(1,1)
	, idTipoCTM INT
	, idReglaNeg INT
);
CREATE TABLE dbo.reglaXtcQdias
(
	idreglaXTc INT PRIMARY KEY
	, valor INT
);
CREATE TABLE dbo.reglaXtcQp
(
	idreglaXTc INT PRIMARY KEY
	, valor INT
);

CREATE TABLE dbo.reglaXtcMontMonet
(
	idreglaXTc INT PRIMARY KEY
	, valor MONEY
);
CREATE TABLE dbo.reglaXtcPorct
(
	idreglaXTc INT PRIMARY KEY
	, valor REAL
);

