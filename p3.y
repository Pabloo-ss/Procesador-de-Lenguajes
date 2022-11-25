%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void yyerror( const char * msg );

#define YYERROR_VERBOSE
%}

/*
Lista Tokens
*/
%start programa
%token PARDER PARIZQ
%token CORDER CORIZQ
%token LLAVEDER LLAVEIZQ
%token CONDFOR CONDWHILE
%token CONDIF CONDELSE
%token MENOS OPERADORBIN OPERADORUNARIO
%token TIPO 
%token LISTA
%token CONS IDEN 
%token PYC COMA
%token ASIG
%token ENTRADA SALIDA
%token CADENA
%token PRINCIPAL DEVOLVER
/*
Lista Preferencias
*/
%left OPERADORBIN
%right OPERADORUNARIO
%left MENOS
%right CONDFOR
%right SALIDA
%right ENTRADA
%left PARDER
%right PARIZQ
%left CORDER
%left CORIZQ
%left LLAVEDER
%right LLAVEIZQ

//Solo se acepta un argumento en la funcion

%%
programa : PRINCIPAL inicio_de_bloque;

inicio_de_bloque : LLAVEIZQ bloque ;

bloque : declar_de_variable_locales bloque
        | declar_de_fun bloque
        | sentencia bloque
        | sentencia_return LLAVEDER     
        ;
    
/*

fin_de_bloque : LLAVEDER ;*/

declar_de_variable_locales :  TIPO  declaracion_v PYC
		| error IDEN
		| error PYC
		;
                
declaracion_v : IDEN 
                | IDEN COMA declaracion_v
                | IDEN ASIG expresion               
                ;

declar_de_fun : TIPO IDEN PARIZQ argumentos PARDER inicio_de_bloque
                ;

sentencias :  sentencias sentencia 
            | 
            ;

sentencia : sentencia_asignacion
            | sentencia_if
            | sentencia_while
            | sentencia_entrada
            | sentencia_salida
            | llamada_func PYC
            | sentencia_for
            | tipo_variable_complejo
            | sentencia_return
            ;



sentencia_asignacion : IDEN ASIG expresion PYC 
                      | iden_lista ASIG expresion PYC 
                      ;

sentencia_if : CONDIF expresion LLAVEIZQ sentencias LLAVEDER
            | CONDIF expresion LLAVEIZQ sentencias LLAVEDER CONDELSE LLAVEIZQ sentencias LLAVEDER
            ;

sentencia_while : CONDWHILE PARIZQ expresion PARDER LLAVEIZQ sentencias LLAVEDER ;

sentencia_entrada : ENTRADA PARIZQ IDEN PARDER PYC ;

sentencia_salida : SALIDA PARIZQ lista_salida PARDER PYC ;

sentencia_for : CONDFOR PARIZQ  sentencia_asignacion expresion PYC expresion PARDER LLAVEIZQ sentencias LLAVEDER ;

sentencia_return : DEVOLVER IDEN PYC
                | DEVOLVER CONS PYC
                ;

llamada_func : IDEN PARIZQ argumentosLlamada PARDER 
		;

lista_salida : lista_salida COMA cadena_expresion
            | cadena_expresion
            ;

cadena_expresion : expresion
                | CADENA
                ;

argumentos : TIPO IDEN COMA argumentos
            | TIPO IDEN
            | error
            ;
          
argumentosLlamada : expresion COMA argumentosLlamada
            | expresion
            | 
            ;

expresion    : expresion OPERADORBIN expresion
            | IDEN
            | CONS
            | MENOS CONS
            | PARIZQ expresion PARDER
            | PARIZQ error PARDER
            | OPERADORUNARIO expresion
            | expresion MENOS expresion
            | llamada_func
            | iden_lista
            ;

tipo_variable_complejo : TIPO LISTA CORIZQ CONS CORDER IDEN ASIG CORIZQ decl_tipo_comp CORDER PYC ;

iden_lista: IDEN CORIZQ CONS CORDER;

/*decl_tipo_comp : decl_tipo_comp_ent
            | decl_tipo_comp_real
            | decl_tipo_comp_booleano
            | decl_tipo_comp_lista
            | %empty
            ;*/

decl_tipo_comp : CONS COMA decl_tipo_comp
                  | CONS
                  ; 

/*<decl_tipo_comp_real> ::= <real>, <decl_tipo_comp_real>
                  |<real>
<decl_tipo_comp_booleano> ::= <booleano>, <decl_tipo_comp_booleano>
                  |<booleano>
<decl_tipo_comp_car> ::= <caracter>, <decl_tipo_comp_car>
                  |<caracter>
<decl_tipo_comp_lista> ::= [<decl_tipo_comp>], <decl_tipo_comp_lista>
                  |[<decl_tipo_comp_lista>]
<constante> ::= <entero>
            |<real>
            |<booleano>
            |<caracter>*/






%%

#include "lex.yy.c"

void yyerror(const char *msg){
  fprintf(stderr, "[Linea %d]: %s\n", yylineno, msg);
}

int main(){
  yyparse();

  return 0;
}

/* Este codigo no da ningun warning y analiza bien todo en test.prog
%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void yyerror( const char * msg );

#define YYERROR_VERBOSE
%}

/*
Lista Tokens
*//*
%start programa
%token PARDER PARIZQ
%token CORDER CORIZQ
%token LLAVEDER LLAVEIZQ
%token CONDFOR CONDWHILE
%token CONDIF CONDELSE
%token MENOS OPERADORBIN OPERADORUNARIO
%token TIPO 
%token LISTA
%token CONS IDEN 
%token PYC COMA
%token ASIG
%token ENTRADA SALIDA
%token CADENA
%token PRINCIPAL DEVOLVER
/*
Lista Preferencias
*//*
%left OPERADORBIN
%right OPERADORUNARIO
%left MENOS
%right CONDFOR
%right SALIDA
%right ENTRADA
%left PARDER
%right PARIZQ
%left CORDER
%left CORIZQ
%left LLAVEDER
%right LLAVEIZQ



%%
programa : PRINCIPAL inicio_de_bloque;

inicio_de_bloque : LLAVEIZQ bloque ;

bloque : declar_de_variable_locales bloque
        | declar_de_fun bloque
        | sentencia bloque
        | sentencia_return LLAVEDER     
        ;
    
/*

fin_de_bloque : LLAVEDER ;*//*

declar_de_variable_locales : TIPO  declaracion_v PYC
                            ;
                
declaracion_v : IDEN 
                | IDEN COMA declaracion_v
                | IDEN ASIG CONS
                ;

declar_de_fun : TIPO IDEN PARIZQ argumentos PARDER inicio_de_bloque
                ;

sentencias :  sentencias sentencia 
            | 
            ;

sentencia : sentencia_asignacion
            | sentencia_if
            | sentencia_while
            | sentencia_entrada
            | sentencia_salida
            | llamada_func
            | sentencia_for
            | tipo_variable_complejo
            | sentencia_return
            ;

sentencia_asignacion : IDEN ASIG expresion PYC ;

sentencia_if : CONDIF expresion LLAVEIZQ sentencias LLAVEDER
            | CONDIF expresion LLAVEIZQ sentencias LLAVEDER CONDELSE LLAVEIZQ sentencias LLAVEDER
            ;

sentencia_while : CONDWHILE PARIZQ expresion PARDER LLAVEIZQ sentencias LLAVEDER ;

sentencia_entrada : ENTRADA PARIZQ IDEN PARDER PYC ;

sentencia_salida : SALIDA PARIZQ lista_salida PARDER PYC ;

sentencia_for : CONDFOR PARIZQ  sentencia_asignacion expresion PYC expresion PARDER LLAVEIZQ sentencias LLAVEDER ;

sentencia_return : DEVOLVER IDEN PYC
                | DEVOLVER CONS PYC
                ;

llamada_func : IDEN PARIZQ expresion PARDER PYC ;

lista_salida : lista_salida COMA cadena_expresion
            | cadena_expresion
            ;

cadena_expresion : expresion
                | CADENA
                ;

argumentos : TIPO IDEN COMA argumentos
            | TIPO IDEN
            | 
            ;

expresion    : expresion OPERADORBIN expresion
            | IDEN
            | CONS
            | MENOS CONS
            | PARIZQ expresion PARDER
            | OPERADORUNARIO expresion
            | llamada_func
            ;

tipo_variable_complejo : LISTA CONS TIPO IDEN ASIG CORIZQ decl_tipo_comp CORDER PYC ;

/*decl_tipo_comp : decl_tipo_comp_ent
            | decl_tipo_comp_real
            | decl_tipo_comp_booleano
            | decl_tipo_comp_lista
            | %empty
            ;*//*

decl_tipo_comp : CONS COMA decl_tipo_comp
                  | CONS
                  ; 

/*<decl_tipo_comp_real> ::= <real>, <decl_tipo_comp_real>
                  |<real>
<decl_tipo_comp_booleano> ::= <booleano>, <decl_tipo_comp_booleano>
                  |<booleano>
<decl_tipo_comp_car> ::= <caracter>, <decl_tipo_comp_car>
                  |<caracter>
<decl_tipo_comp_lista> ::= [<decl_tipo_comp>], <decl_tipo_comp_lista>
                  |[<decl_tipo_comp_lista>]
<constante> ::= <entero>
            |<real>
            |<booleano>
            |<caracter>*//*






%%

#include "lex.yy.c"

void yyerror(const char *msg){
  fprintf(stderr, "[Linea %d]: %s\n", yylineno, msg);
}

int main(){
  yyparse();

  return 0;
}
*/
