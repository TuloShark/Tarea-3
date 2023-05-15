ALTER FUNCTION dbo.CumpleFecha
(
	 @InFechaOperacion DATE
	,@InFechaEmpleado DATE
)
RETURNS INT
AS
BEGIN
	DECLARE @MesOperacion INT
	DECLARE @OutResult INT
	SET @OutResult = 0
	SET @MesOperacion = MONTH(@InFechaOperacion)

	IF (DAY(@InFechaOperacion)= 29 OR DAY(@InFechaOperacion) = 28 AND @MesOperacion = 2)
		BEGIN
			IF (DAY(@InFechaEmpleado)=30 OR DAY(@InFechaEmpleado)=31)
			BEGIN
				SET @OutResult = 1
			END
		END

	 IF (DAY(@InFechaOperacion)= 30 AND (@MesOperacion= 4 OR @MesOperacion = 6 OR
			@MesOperacion = 9 OR @MesOperacion= 11))
			BEGIN 
				IF(DAY(@InFechaEmpleado)=31)
				BEGIN
					SET @OutResult = 1
				END
			END

	IF (DAY(@InFechaEmpleado)=DAY(@InFechaOperacion))
			BEGIN
				SET @OutResult = 1
			END 	
	RETURN @OutResult
END

