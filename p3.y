%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void yyerror( const char * msg );

#define YYERROR_VERBOSE

#define NONEDIM -1

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

//Si tEntrada es funcion, variable, o parametro-formal; indica el tipo

typedef enum {
      entero,
      caracter,
      real,
      booleano,
      listaEntero,
      listaReal,
      listaCaracter,
      listaBooleano,
      error
} tSimbolo ;
// tSimbolo indica el tipo de la variable
typedef struct {
      tEntrada entrada ;
      char *nombre ;
      tSimbolo tipoDato ;
      unsigned int parametros ;
      unsigned int dimension ;
      // int TamDim1 ; para las listas tambien no ??
} entradaTS ;
//Se usa para formar


#define MAX_TS 500 //tamaño maximo de la pila

long int TOPE=0 ; /* Tope de la pila */
unsigned int Subprog = 0 ; /* Indicador de comienzo de bloque de un Subprog */
entradaTS TS[MAX_TS] ; /* Pila de la tabla de símbolos */
tSimbolo tipoTmp; // Tipo auxiliar para declaración de variables

typedef struct {
      int atrib ; /* Atributo del símbolo (si tiene) */
      char *  lexema ; /* Nombre del lexema */
      tSimbolo tipo ; /* Tipo del símbolo */
} atributos ;

#define YYSTYPE atributos

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

tSimbolo aTipoLista(tSimbolo ts){
  switch (ts) {
    case real:
      return listaReal;
    case entero:
      return listaEntero;
    case booleano:
      return listaBooleano;
    case caracter:
      return listaCaracter;
    case error:
      return error;
    default:
      fprintf(stderr, "Error en aTipoLista(), no se conoce el tipo dato\n");
      exit(EXIT_FAILURE);
  }
}

tSimbolo listaATipo(tSimbolo ts){
  switch (ts) {
    case listaReal:
      return real;
    case listaEntero:
      return entero;
    case listaBooleano:
      return booleano;
    case listaCaracter:
      return caracter;
    case error:
      return error;
    default:
      fprintf(stderr, "Error en listaATipo(), no se conoce el tipo dato (%s)\n", tipoAString(ts));
      exit(EXIT_FAILURE);
  }
}

int esLista(tSimbolo tipo_dato){
  return tipo_dato == listaEntero || tipo_dato == listaReal || tipo_dato == listaBooleano || tipo_dato == listaCaracter;
}

int esNumero(tSimbolo tipo_dato){
  return tipo_dato == entero || tipo_dato == real;
}

int esEntero(tSimbolo tipo_dato){
  return tipo_dato == entero;
}

int esReal(tSimbolo tipo_dato){
  return tipo_dato == real;
}

tSimbolo tipoCons(char* cons){
  tSimbolo a = error;

  switch(*cons){
      case 'v': a = booleano; break;
      case 'f': a = booleano; break;
      case '\'': a = caracter; break;
      default: a = entero;
  }

  for(int i = 0; i != '\0'; i++){
    if(*(cons + i) == '.'){
      a = real;

    }       // Aqui que se hace que no lo entiendo????????????
  }

  return a;
}

void imprimir() {
  for (int i = 0; i <= TOPE; ++i) {
    printf("[%i]: ", i);
    switch(TS[i].entrada) { //aqui seria entrada en vez de tEntrada no ?
      case variable:
        printf("Variable %s, tipo: %s\n", TS[i].nombre,
            tipoAString(TS[i].tipoDato));
        break;
      case funcion:
        printf("Funcion %s, tipo: %s, nº parametros: %i\n", TS[i].nombre,
            tipoAString(TS[i].tipoDato), TS[i].parametros);
        break;
      case marca:
        printf("Marca\n");
        break;
      case parametro_formal:
        printf("Parametro formal %s, tipo: %s\n", TS[i].nombre,
            tipoAString(TS[i].tipoDato));
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
  for (int i = TOPE; !repetida && TS[i].entrada != marca; --i) {
    if (TS[i].entrada != parametro_formal && !strcmp(TS[i].nombre, id)) {  // ******* Aqui creo q la primera sentencia del if seria == en vez de != pq aunq sea argumento de la funcion no queremos que se repita el nombre no?
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
  if (TOPE + 1 >= MAX_TS) { //Seria TOPE EN MAYUCULAS NO ?
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
  while(i >= 0 && (TS[i].entrada == parametro_formal || strcmp(id, TS[i].nombre)))
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
  if (Subprog) {
    for (int i = TOPE - 1; TS[i].entrada != funcion; --i) {
      insertarEntrada(variable, TS[i].nombre, TS[i].tipoDato, -1, TS[i].dimension); 
    }
    Subprog = 0;
  }
}

void vaciarEntradas() {
  // Hasta la última marca borramos todo
  while (TS[TOPE].entrada != marca)
    --TOPE;
  // Elimina la última marca
  --TOPE;
}

void insertarVariable(char* id, int dimension) {
  // Comprobamos que no esté repetida la id
  idRepetida(id);
  insertarEntrada(variable, id, tipoTmp, -1, dimension);   
}

void insertarFuncion(tSimbolo tipoDato, char* id) {
  // Comprobamos que el id no esté usado ya
  idRepetida(id);
  insertarEntrada(funcion, id, tipoDato, 0, -1);
}

void insertarParametro(tSimbolo tipoDato, char* id) {
  // Comprobamos que no haya parámetros con nombres repetidos
  // Además guardamos el índice de la función
  int i;
  int parametroRepetido = 0;
  for (i = TOPE; !parametroRepetido && TS[i].entrada != funcion; --i) {
    if (!strcmp(TS[i].nombre, id)) {
      sprintf(msgError, "ERROR SINTÁCTICO: identificador del parámetro %s ya declarado\n", id);
      yyerror(msgError);
      parametroRepetido = 1;
    
    }
  }
  // Añadimos la entrada
  insertarEntrada(parametro_formal, id, tipoDato, -1, NONEDIM); // ********** una vez mas de dnd sacar la dimension ************
  // Actualizamos el nº de parámetros de la función
  ++TS[i].parametros;
}

tSimbolo buscarID(char* id) {
  int i = buscarEntrada(id);

  if (i < 0)
    return error;
  return TS[i].tipoDato;
}

void comprobarAsignacion(char* id, tSimbolo ts) {
  int i = buscarEntrada(id);
  if (i >= 0) {
    if (TS[i].entrada != variable) {
      sprintf(msgError, "ERROR SINTÁCTICO: se intenta asignar a %s, y no es una variable\n", id);
      yyerror(msgError);
    } else {
      if (TS[i].tipoDato == listaBooleano || TS[i].tipoDato == listaReal || TS[i].tipoDato == listaEntero || TS[i].tipoDato == listaCaracter){
        if (ts == error || ts != listaATipo(TS[i].tipoDato)) {
          sprintf(msgError, "ERROR SINTÁCTICO: asignación incorrecta, %s es tipo %s y se obtuvo %s\n", id, tipoAString(TS[i].tipoDato), tipoAString(ts));
          yyerror(msgError);
        }
      }else{
        if (ts == error || ts != TS[i].tipoDato) {
          sprintf(msgError, "ERROR SINTÁCTICO: asignación incorrecta, %s es tipo %s y se obtuvo %s\n", id, tipoAString(TS[i].tipoDato), tipoAString(ts));
          yyerror(msgError);
        }
      }
    }
  }
}

void isBooleana(tSimbolo ts) {
  if (ts == error || ts != booleano) {
    sprintf(msgError, "ERROR SINTÁCTICO: condición no es de tipo booleano, se tiene tipo %s", tipoAString(ts));
    yyerror(msgError);
  }
}

tSimbolo andLog(tSimbolo ts1, tSimbolo ts2) {
  if (ts1 == error || ts2 == error)
    return error;

  if (ts1 != booleano || ts2 != booleano) {
    sprintf(msgError, "ERROR SINTÁCTICO: operador and no aplicable a los tipos %s, %s\n", tipoAString(ts1), tipoAString(ts2));
    yyerror(msgError);
    return error;
  }

  return booleano;
}

tSimbolo orLog(tSimbolo ts1, tSimbolo ts2) {
  if (ts1 == error || ts2 == error)
    return error;

  if (ts1 != booleano || ts2 != booleano) {
    sprintf(msgError, "ERROR SINTÁCTICO: operador or no aplicable a los tipos %s, %s\n",   tipoAString(ts1), tipoAString(ts2));
    yyerror(msgError);
    return error;
  }

  return booleano;
}

tSimbolo eq(tSimbolo ts1, tSimbolo ts2) {
  if (ts1 == error || ts2 == error)
    return error;

  if (ts1 != ts2) {
    sprintf(msgError, "ERROR SINTÁCTICO: operador == no aplicable a los tipos %s, %s\n", tipoAString(ts1), tipoAString(ts2));
    yyerror(msgError);
    return error;
  }

  return booleano;
}
tSimbolo opBinario(tSimbolo ts1, int atr, tSimbolo ts2) { 
  if (ts1 == error || ts2 == error) 
    return error; 
 
  switch(atr){ 
    case 0: // * 
      if(ts1 == entero && ts2 == entero) 
        return entero; 
      else if(ts1 == real && ts2 == real) 
        return real; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador * no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 1: // / 
      if(ts1 == entero && ts2 == entero) 
        return entero; 
      else if(ts1 == real && ts2 == real) 
        return real; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador / no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 2: // or 
      if(ts1 == booleano && ts2 == booleano) 
        return booleano; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador or no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 3: // and 
      if(ts1 == booleano && ts2 == booleano) 
        return booleano; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador and no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 4:// xor 
      if(ts1 == booleano && ts2 == booleano) 
        return booleano; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador xor no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 5://  == 
      if(ts1 == booleano && ts2 == booleano) 
        return booleano; 
      else if(ts1 == caracter && ts2 == caracter) 
        return booleano; 
      else if(ts1 == entero && ts2 == entero) 
        return booleano; 
      else if(ts1 == real && ts2 == real) 
        return booleano; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador == no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 6:// < 
      if(ts1 == entero && ts2 == entero) 
        return entero; 
      else if(ts1 == real && ts2 == real) 
        return real; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador < no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 7:// > 
      if(ts1 == entero && ts2 == entero) 
        return entero; 
      else if(ts1 == real && ts2 == real) 
        return real; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador > no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
    case 8: // + 
      if(ts1 == entero && ts2 == entero) 
        return entero; 
      else if(ts1 == real && ts2 == real) 
        return real; 
      else{ 
        sprintf(msgError, "ERROR SINTÁCTICO: operador + no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
      break; 
  } 
}

void menosUnarioAplicable(tSimbolo ts){
  if(!(ts == entero || ts == real)){
    sprintf(msgError, "ERROR SINTÁCTICO: el operador - no es aplicable al tipo %s\n", tipoAString(ts));
    yyerror(msgError);
  }
}

void opUnarioAplicable(tSimbolo ts){
  if(ts != booleano){
    sprintf(msgError, "ERROR SINTÁCTICO: el operador not no es aplicable al tipo %s\n", tipoAString(ts));
    yyerror(msgError);
  }
}

void comprobarDimen(tSimbolo ts){
  if(!esEntero(ts)){
    sprintf(msgError, "ERROR SINTÁCTICO: el tipo %s no es válido como dimensión \n", tipoAString(ts));
    yyerror(msgError);
  }
}

void comprobarDevolver(tSimbolo ts){
  int i = TOPE;
  int marcaEncontrada = 0;
  int funcionEncontrada = 0;

  while (i >= 1 && !funcionEncontrada) {
    funcionEncontrada = marcaEncontrada && TS[i].entrada == funcion;
    marcaEncontrada = (!marcaEncontrada && TS[i].entrada == marca) ||
                      (marcaEncontrada && TS[i].entrada == parametro_formal);
    --i;
  }

  if (funcionEncontrada) ++i;

  if (i <= 0) {
    sprintf(msgError, "ERROR SINTÁCTICO: return no asignado a ninguna función\n");
    yyerror(msgError);
  } else if (ts != error && ts != TS[i].tipoDato) {
    sprintf(msgError, "ERROR SINTÁCTICO: return devuelve tipo %s, y función es de tipo %s\n",  tipoAString(ts), tipoAString(TS[i].tipoDato));
    yyerror(msgError);
  }
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

inicio_de_bloque : LLAVEIZQ bloque  {insertarMarca(); }

bloque : declar_de_variable_locales bloque
        | declar_de_fun bloque
        | sentencia bloque
        | sentencia_return LLAVEDER  {vaciarEntradas(); Subprog = 0;}
        ;
    


declar_de_variable_locales :  TIPO  declaracion_v PYC               
		| error IDEN
		| error PYC {yyerrok;}
		;
                
declaracion_v :   IDEN   {tipoTmp = $0.atrib; insertarVariable($1.lexema, NONEDIM);}
                | IDEN COMA declaracion_v  {insertarVariable($1.lexema, NONEDIM);}
                | IDEN ASIG expresion     {insertarVariable($1.lexema, NONEDIM); comprobarAsignacion($1.lexema, $3.tipo);}
                ;

declar_de_fun : TIPO IDEN PARIZQ {insertarFuncion($1.atrib, $2.lexema);} argumentos PARDER inicio_de_bloque { Subprog = 1;}
                ;

sentencias :  sentencias sentencia 
            | 
            ;

sentencia : sentencia_asignacion PYC
            | sentencia_if
            | sentencia_while
            | sentencia_entrada
            | sentencia_salida
            | llamada_func PYC
            | sentencia_for
            | tipo_variable_complejo
            | sentencia_return
            ;



sentencia_asignacion : IDEN ASIG expresion                        {buscarEntrada($1.lexema); comprobarAsignacion($1.lexema, $3.tipo);}
                      | iden_lista ASIG expresion                 {buscarEntrada($1.lexema); comprobarAsignacion($1.lexema, $3.tipo);}
                      ;                                            //Igual este buscarEntrada sobra

sentencia_if : CONDIF expresion LLAVEIZQ sentencias LLAVEDER                                          {isBooleana($2.tipo);}
            | CONDIF expresion LLAVEIZQ sentencias LLAVEDER CONDELSE LLAVEIZQ sentencias LLAVEDER     {isBooleana($2.tipo);}
            ;

sentencia_while : CONDWHILE PARIZQ expresion PARDER LLAVEIZQ sentencias LLAVEDER  {isBooleana($3.tipo);}

sentencia_entrada : ENTRADA PARIZQ IDEN PARDER PYC          {buscarEntrada($3.lexema);}

sentencia_salida : SALIDA PARIZQ lista_salida PARDER PYC ;            

sentencia_for : CONDFOR PARIZQ  sentencia_asignacion PYC expresion PYC sentencia_asignacion PARDER LLAVEIZQ sentencias LLAVEDER   {isBooleana($5.tipo);} 

sentencia_return : DEVOLVER IDEN PYC                {buscarEntrada($2.lexema); comprobarDevolver($2.tipo); $$.tipo = buscarID($2.lexema);}
                | DEVOLVER CONS PYC                 {$2.tipo = tipoCons($2.lexema); comprobarDevolver($2.tipo); $$.tipo = $2.tipo;}
                ;

llamada_func : IDEN PARIZQ argumentosLlamada PARDER    {buscarEntrada($1.lexema);}

lista_salida : lista_salida COMA cadena_expresion
            | cadena_expresion
            ;

cadena_expresion : expresion
                | CADENA
                ;

argumentos : TIPO IDEN COMA argumentos                                {insertarParametro($1.atrib, $2.lexema);imprimir();}
            | TIPO IDEN                                               {insertarParametro($1.atrib, $2.lexema);}
            | error
            ;
          
argumentosLlamada : expresion COMA argumentosLlamada
            | expresion
            | 
            ;

expresion    : expresion OPERADORBIN expresion                        {$$.tipo = opBinario($1.tipo, $2.atrib, $3.tipo);}
            | IDEN                                                    {$$.tipo = buscarEntrada($1.lexema);}
            | CONS                                                    {$1.tipo = tipoCons($1.lexema);}
            | MENOS CONS                                              {$2.tipo = tipoCons($2.lexema); menosUnarioAplicable($2.tipo);}
            | PARIZQ expresion PARDER
            | OPERADORUNARIO expresion                                {opUnarioAplicable($2.tipo);}
            | expresion MENOS expresion
            | llamada_func
            | iden_lista
            | error
            ;

tipo_variable_complejo : TIPO LISTA CORIZQ CONS CORDER IDEN ASIG CORIZQ decl_tipo_comp CORDER PYC   {comprobarDimen(tipoCons($4.lexema));tipoTmp = aTipoLista($1.atrib); insertarVariable($6.lexema, 4 ); comprobarAsignacion($6.lexema, $9.tipo);}
                                                                                                        //Como se recupera el valor de la cons para meterlo como dimensión????
iden_lista: IDEN CORIZQ CONS CORDER  {$$.tipo=buscarEntrada($1.lexema);}

/*decl_tipo_comp : decl_tipo_comp_ent
            | decl_tipo_comp_real
            | decl_tipo_comp_booleano
            | decl_tipo_comp_lista
            | %empty
            ;*/

decl_tipo_comp : CONS COMA decl_tipo_comp                         {$1.tipo = tipoCons($1.lexema);}
                  | CONS                                          {$1.tipo = tipoCons($1.lexema);}
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