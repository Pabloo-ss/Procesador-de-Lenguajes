%option yylineno
%option noyywrap

letra	[a-zA-Z]
digito	[0-9]
otros	[\n\t ]
%%
")"						                                    {return PARDER;}
"("						                                    {return PARIZQ;}
"]"						                                    {return CORDER;}
"["						                                    {return CORIZQ;}
"}"						                                    {return LLAVEDER;}
"{"						                                    {return LLAVEIZQ;}
"para"						                                {return CONDFOR;}
"mientras"					                                {return CONDWHILE;}
"si"						                                {return CONDIF;}
"sino"						                                {return CONDELSE;}
"entrada"					                                {return ENTRADA;}
"salida"					                                {return SALIDA;}
"devolver"					                                {return DEVOLVER;}
"principal"					                                {return PRINCIPAL;}
\"[^\"]*\"					                                {yylval.lexema = strdup(yytext); yylval.tipo = cadena; return CADENA; }
","						                                    {return COMA;}
"-"						                                    {yylval.atrib = 12; yylval.lexema = strdup(yytext);return MENOS;}

"<"                                                 {yylval.atrib = 6; yylval.lexema = strdup(yytext);return OPERADORBIN;}
"<="                                                {yylval.atrib = 9; yylval.lexema = strdup(yytext);return OPERADORBIN;}
">="                                               {yylval.atrib = 10; yylval.lexema = strdup(yytext);return OPERADORBIN;}
"!="                                               {yylval.atrib = 11; yylval.lexema = strdup(yytext);return OPERADORBIN;}
"*"|"/"|"or"|"and"|"xor"|"=="|">"|"+"              {int a = -1;
                                                                switch(*yytext){
                                                                    case '*': a = 0; break;
                                                                    case '/': a = 1; break;
                                                                    case 'o': a = 2; break;
                                                                    case 'a': a = 3; break;
                                                                    case 'x': a = 4; break;
                                                                    case '=': a = 5; break;
                                                                    case '>': a = 7; break;
                                                                    case '+': a = 8; break;
                                                                    
                                                                }
                                                                yylval.atrib = a; yylval.lexema = strdup(yytext);return OPERADORBIN;}

"not" 						                                {return OPERADORUNARIO;}
"ent"|"car"|"real"|"booleano"			                    {int a = -1;
                                                                switch(*yytext){
                                                                    case 'e': a = 0; break;
                                                                    case 'c': a = 1; break;
                                                                    case 'r': a = 2; break;
                                                                    case 'b': a = 3; break;
                                                                }
                                                                yylval.atrib = a; return TIPO;}

"lista"						                                {return LISTA;}

{digito}+|{digito}+.{digito}+|"verdadero"|"falso"|\'[^\']\'	{int a = -1;
                                                                switch(*yytext){
                                                                    case 'v': a = 3; break;
                                                                    case 'f': a = 3; break;
                                                                    case '\'': a = 2; break;
                                                                    default: a = 0;
                                                                }
                                                                yylval.atrib = a; yylval.lexema = strdup(yytext); return CONS;}

{letra}({letra}|{digito})*			                        {yylval.lexema = strdup (yytext); return IDEN;}
";"						                                    {return PYC;}
"="						                                    {return ASIG;}
{otros}		
.			                	                {printf("Error en la l??nea %d. Caracter %s no reconocible.\n", yylineno, yytext);};

%%

