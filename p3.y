%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void yyerror( const char * msg );

#define YYERROR_VERBOSE
#define MAX_TS 500

// Esto elimina un Warning, no debería cambiar nada más.
int yylex();

char msgError[256];

/************************/
/* ESTRUCTURA DE LA TS */
/***********************/

typedef enum {
      marca, /* marca comienzo bloque */
      funcion, /* si es subprograma */
      variable, /* si es variable */
      parametro_formal, /* si es parametro formal */
} tEntrada ;

typedef enum {
      entero,
      real,
      caracter,
      booleano,
      listaEntero,
      listaReal,
      listaCaracter,
      listaBooleano,
      error
} tSimbolo ;

typedef struct {
      tEntrada entrada ;
      char *nombre ;
      tSimbolo tipoDato ;
      unsigned int parametros ;
      unsigned int dimension ;
} entradaTS ;


long int TOPE=0 ; /* Tope de la pila */
unsigned int Subprog ; /* Indicador de comienzo de bloque de un subprog */
entradaTS TS[MAX_TS] ; /* Pila de la tabla de símbolos */

typedef struct {
      int atrib ; /* Atributo del símbolo (si tiene) */
      char *  lexema ; /* Nombre del lexema */
      tSimbolo tipo ; /* Tipo del símbolo */
} atributos ;

/* Inicio funciones auxiliares */

char* tipoAString(tSimbolo tipo_dato) {
  switch (tipo_dato) {
    case real:
      return "float";
    case entero:
      return "int";
    case booleano:
      return "bool";
    case caracter:
      return "char";
    case listaReal:
      return "list_of float";
    case listaEntero:
      return "list_of int";
    case listaCaracter:
      return "list_of char";
    case listaBooleano:
      return "list_of bool";
    case error:
      return "error";
    default:
      fprintf(stderr, "Error en tipoAString(), no se conoce el tipo dato\n");
      exit(EXIT_FAILURE);
  }
}

int esLista(tSimbolo tipo_dato){
  return tipo_dato == listaEntero || tipo_dato == listaReal || tipo_dato == listaBooleano || tipo_dato == listaCaracter;
}

int esNumero(TipoDato tipo_dato){
  return tipo_dato == entero || tipo_dato == real;
}

void imprimir() {
  for (int i = 0; i <= TOPE; ++i) {
    printf("[%i]: ", i);
    switch(TS[i].tEntrada) {
      case variable:
        printf("Variable %s, tipo: %s\n", ts[i].nombre,
            tipoAString(ts[i].tipoDato));
        break;
      case funcion:
        printf("Funcion %s, tipo: %s, nº parametros: %i\n", ts[i].nombre,
            tipoAString(ts[i].tipoDato), ts[i].parametros);
        break;
      case marca:
        printf("Marca\n");
        break;
      case parametroFormal:
        printf("Parametro formal %s, tipo: %s\n", ts[i].nombre,
            tipoAString(ts[i].tipoDato));
        break;
      default:
        fprintf(stderr, "Error en imprimir(), no debería salir\n");
        exit(EXIT_FAILURE);
    }
  }
}

void idRepetida(char* id) {
  // Miramos si id estaba declarado después de la última marca
  int repetida = 0;
  for (int i = TOPE; !repetida && ts[i].entrada != marca; --i) {
    if (ts[i].entrada != parametroFormal && !strcmp(ts[i].nombre, id)) {  // ******* Aqui creo q la primera sentencia del if seria == en vez de != pq aunq sea argumento de la funcion no queremos que se repita el nombre no?
      sprintf(msgError, "ERROR SINTÁCTICO: identificador %s ya declarado\n", id);
      yyerror(msgError);
      repetida = 1;
    }
  }
}

void insertarEntrada(tEntrada te, char* nombre, tSimbolo tipo_dato, int nParam, int dimension) {
  // Hacemos la entrada
  entradaTS entrada = {
    te,
    strdup(nombre),
    tipo_dato,
    nParam,
    dimension
  };

  // Si la tabla está llena da error
  if (tope + 1 >= MAX_TS) {
    sprintf(msgError, "ERROR SINTÁCTICO: La tabla de símbolos está llena\n");
    yyerror(msgError);
  }
  // Aumentamos el tope
  ++TOPE;
  // Añadimos la nueva entrada
  TS[TOPE] = entrada;
}

// Busca una entrada en la TS con el id especificado en el ámbito del programa
// actual. Si no lo encuentra, devuelve -1. No gestiona errores!
int buscarEntrada(char* id) {
  int i = TOPE;
  while(i >= 0 && (ts[i].tEntrada == parametroFormal || strcmp(id, ts[i].nombre)))
    --i;

  if (i < 0) {
    sprintf(msgError, "ERROR SINTÁCTICO: identificador %s no declarado\n", id);
    yyerror(msgError);
  }
  return i;
}


/* Fin funciones auxiliares */

/* Lista de funciones y procedimientos para manejo de la TS */

void insertarMarca() {
  // Metemos la marca
  insertarEntrada(marca, "", -1, -1, -1);
  // Si es subprograma añadimos las variables al bloque
  if (subProg) {
    for (int i = TOPE - 1; ts[i].tipoEntrada != funcion; --i) {
      insertarEntrada(variable, ts[i].nombre, ts[i].tipoDato, -1, ts[i].dimension); 
    }
    subProg = 0;
  }
}

void vaciarEntradas() {
  // Hasta la última marca borramos todo
  while (ts[tope].tipoEntrada != marca)
    --tope;
  // Elimina la última marca
  --tope;
}

void insertarVariable(char* id) {
  // Comprobamos que no esté repetida la id
  idRepetida(id);
  insertarEntrada(variable, id, , -1, );    // **********  De dnd sacar el tipo y la dimension en caso de tenerla *******
}

void insertarFuncion(tSimbolo tipoDato, char* id) {
  // Comprobamos que el id no esté usado ya
  idRepetida(id);
  insertarEntrada(funcion, id, tipoDato, 0, -1); // **********  De dnd sacar el tipo *******
}

void insertarParametro(tSimbolo tipoDato, char* id) {
  // Comprobamos que no haya parámetros con nombres repetidos
  // Además guardamos el índice de la función
  int i;
  int parametroRepetido = 0;
  for (i = TOPE; !parametroRepetido && ts[i].tipoEntrada != funcion; --i) {
    if (!strcmp(ts[i].nombre, id)) {
      sprintf(msgError, "ERROR SINTÁCTICO: identificador del parámetro %s ya declarado\n", id);
      yyerror(msgError);
      parametroRepetido = 1;
    }
  }
  // Añadimos la entrada
  insertarEntrada(parametroFormal, id, tipoDato, -1, ); // ********** una vez mas de dnd sacar la dimension ************
  // Actualizamos el nº de parámetros de la función
  ++ts[i].parametros;
}

tSimbolo buscarID(char* id) {
  int i = buscarEntrada(id);

  if (i < 0)
    return error;
  return ts[i].tipoDato;
}



/* Fin de funciones y procedimientos para manejo de la TS */


#define YYSTYPE atributos /* Cada símbolo tiene una estructura de tipo atributos */

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
		| error PYC {yyerrok;}
		;
                
declaracion_v :   IDEN 
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
            | OPERADORUNARIO expresion
            | expresion MENOS expresion
            | llamada_func
            | iden_lista
            | error
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
