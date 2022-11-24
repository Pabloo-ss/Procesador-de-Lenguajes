%option yylineno
%option noyywrap

letra	[a-z]
digito	[0-9]
otros	[\n\t ]
%%
")"						                                    return PARDER;
"("						                                    return PARIZQ;
"]"						                                    return CORDER;
"["						                                    return CORIZQ;
"}"						                                    return LLAVEDER;
"{"						                                    return LLAVEIZQ;
"para"						                                return CONDFOR;
"mientras"					                                return CONDWHILE;
"si"						                                return CONDIF;
"sino"						                                return CONDELSE;
"entrada"					                                return ENTRADA;
"salida"					                                return SALIDA;
"devolver"					                                return DEVOLVER;
"principal"					                                return PRINCIPAL;
\"[^\"]+\"					                                return CADENA;
","						                                    return COMA;
"-"						                                    return MENOS;
"*"|"/"|"or"|"and"|"xor"|"=="|"<"|">"|"+"	                return OPERADORBIN;
"not" 						                                return OPERADORUNARIO;
"ent"|"car"|"real"|"booleano"			                    return TIPO;
"lista"						                                return LISTA;
{digito}+|{digito}+.{digito}+|"verdadero"|"falso"|\'[^\']\'	return CONS;
{letra}({letra}|{digito})*			                        return IDEN;
";"						                                    return PYC;
"="						                                    return ASIG;
{otros}		
.			                	                {printf("Error en la línea %d. Lexema %s no reconocible.\n", yylineno, yytext);};

%%

