float max (float num1, float num2){
float maximo;
int temp1;
temp1 = num1 >= num2; 
if (!temp1) goto etiqueta1;
{
	
{
	maximo = num1;
}
}
goto etiqueta2;

etiqueta1:
{
	
{
	maximo = num2;
}
}

etiqueta2: {} 
float min (float numero1, float numero2){
float minimo;
int temp2;
temp2 = num1 <= num2; 
if (!temp2) goto etiqueta3;
{
	
{
	minimo = num1;
}
}
goto etiqueta4;

etiqueta3:
{
	
{
	minimo = num2;
}
}

etiqueta4: {} 
return minimo;
}
return maximo;
}
