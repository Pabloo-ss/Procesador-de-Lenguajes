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
%left PARDER
%right PARIZQ
%left CORDER
%right CORIZQ
%left LLAVEDER
%right LLAVEIZQ
%right OPERADORBIN
%left MENOS
%right CONDFOR


%%
programa : PRINCIPAL bloque;

bloque : LLAVEIZQ   
        | declar_de_variable_locales    
        | declar_de_fun     
        | sentencias        
        | sentencia_return  
        | LLAVEDER     
        ;
    
/*inicio_de_bloque : LLAVEIZQ ;

fin_de_bloque : LLAVEDER ;*/

declar_de_variable_locales : TIPO  declaracion_v PYC
                            | 
                            ;
                
declaracion_v : IDEN
                | IDEN COMA declaracion_v
                ;

declar_de_fun : declar_de_fun TIPO IDEN PARIZQ argumentos PARDER bloque
                | 
                ;

sentencias :  sentencias sentencia 
            | sentencia
            ;

sentencia : sentencia_asignacion
            | sentencia_if
            | sentencia_while
            | sentencia_entrada
            | sentencia_salida
            | llamada_func
            | sentencia_for
            | tipo_variable_complejo
            |
            ;

sentencia_asignacion : IDEN ASIG expresion PYC ;

sentencia_if : CONDIF expresion LLAVEIZQ sentencias LLAVEDER
            | CONDIF expresion LLAVEIZQ sentencias LLAVEDER CONDELSE LLAVEIZQ sentencias LLAVEDER
            ;

sentencia_while : CONDWHILE PARIZQ expresion PARDER LLAVEIZQ sentencias LLAVEDER ;

sentencia_entrada : ENTRADA PARIZQ IDEN PARDER PYC ;

sentencia_salida : SALIDA PARIZQ lista_salida PARDER PYC ;

sentencia_for : CONDFOR PARIZQ  sentencia_asignacion expresion PYC expresion PARDER LLAVEIZQ sentencias LLAVEDER ;

sentencia_return : DEVOLVER IDEN
                | DEVOLVER CONS
                ;

llamada_func : IDEN PARIZQ expresion PYC ;

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
