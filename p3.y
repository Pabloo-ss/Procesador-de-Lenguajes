
/*
! ya lee todo el programa completo aunque falla al meter las cosas en la ts. Creo que si se arregla 
! lo de abajo se arregla
TODO Falla en los operadores, al realizar la operacion no se puede devolver entero o flotante unicamente hay que rehacer el metodo creo* 
*/
%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

FILE* yyout;

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
      descriptor,
} tEntrada ;

// Para bucles if
typedef struct {
  char* etiquetaEntrada;
  char* etiquetaSalida;
  char* etiquetaElse;
} DescriptorDeInstrControl;

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
} tSimbolo ;// tSimbolo indica el tipo de la variable

typedef struct {
      tEntrada entrada ;
      char *nombre ;
      tSimbolo tipoDato ;
      unsigned int parametros ;
      unsigned int dimension ;
      DescriptorDeInstrControl* descriptor; // Descriptor de control (bucles IF - intermedio)
      // int TamDim1 ; para las listas tambien no ??
} entradaTS ;
//Se usa para formar


#define MAX_TS 500 //tamaño maximo de la pila

long int TOPE=0 ; /* Tope de la pila */
unsigned int Subprog = 0 ; /* Indicador de comienzo de bloque de un Subprog */
int numArgs[2] = {0,0};
int numArgs_llevados =0;
int error_args=0;
entradaTS TS[MAX_TS] ; /* Pila de la tabla de símbolos */
tSimbolo tipoTmp; // Tipo auxiliar para declaración de variables

typedef struct {
      int atrib ; /* Atributo del símbolo (si tiene) */
      char *  lexema ; /* Nombre del lexema */
      tSimbolo tipo ; /* Tipo del símbolo */
      char codigo[500];
      char valor[100];
} atributos ;


#define YYSTYPE atributos

/* *Inicio funciones auxiliares */

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
      return "list float";
    case listaEntero:
      return "list int";
    case listaCaracter:
      return "list char";
    case listaBooleano:
      return "list bool";
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

  
  for(int i = 0; i != '\n'; i++){
    if(*(cons + i) == '.'){
      a = real;

    }   
  }
  

  return a;
}

void imprimir() {
  for (int i = 0; i <= TOPE; ++i) {
    printf("[%i]: ", i);
    switch(TS[i].entrada) { 
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
    if(i==TOPE)printf("-------------------------------------------------\n");
  }
}

void idRepetida(char* id) {
  // Miramos si id estaba declarado después de la última marca
  int repetida = 0;
  for (int i = TOPE; !repetida && TS[i].entrada != marca; --i) {
    if (TS[i].entrada != parametro_formal && !strcmp(TS[i].nombre, id)) {  
      sprintf(msgError, "ERROR SEMANTICO: identificador %s ya declarado\n", id);
      yyerror(msgError);
      repetida = 1;
    }
  }
}

void insertarEntrada(tEntrada te, char* nombre, tSimbolo tipo_dato, int nParam, int dimension, DescriptorDeInstrControl* descp) {
  // Hacemos la entrada
  entradaTS entrada = {
    te,
    strdup(nombre),
    tipo_dato,
    nParam,
    dimension,
    descp
  };

  // Si la tabla está llena da error
  if (TOPE + 1 >= MAX_TS) {
    sprintf(msgError, "ERROR SEMANTICO: La tabla de símbolos está llena\n");
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
  while(i > 0){
    if(!(TS[i].entrada == parametro_formal || strcmp(id, TS[i].nombre)))
      break;
    --i;
  }

  if (i <= 0) {
    sprintf(msgError, "ERROR SEMANTICO: identificador %s no declarado\n", id);
    yyerror(msgError);
  }
  return i;
}

int numeroArg(char * id){
  int i = TOPE;
  while(i > 0){
    if(!(TS[i].entrada == parametro_formal || strcmp(id, TS[i].nombre)))
      break;
    --i;
  }
  
  return TS[i].parametros;
}

/* *Fin funciones auxiliares */

/* *Lista de funciones y procedimientos para manejo de la TS */

void insertarMarca() {
  // Metemos la marca
  insertarEntrada(marca, " ", -1, -1, -1, NULL);
  // Si es subprograma añadimos las variables al bloque
  if (Subprog) {
    for (int i = TOPE - 1; TS[i].entrada != funcion; --i) {
      insertarEntrada(variable, TS[i].nombre, TS[i].tipoDato, -1, -1, NULL); 
    }
    Subprog = 0;
  }
}

void vaciarEntradas() {
  // Hasta la última marca borramos todo
  while (TS[TOPE].entrada != marca) --TOPE;
  // Elimina la última marca
  --TOPE;
  
}

void insertarVariable(char* id, int dimension) {
  // Comprobamos que no esté repetida la id
  idRepetida(id);
  insertarEntrada(variable, id, tipoTmp, -1, dimension, NULL);   
}

void insertarFuncion(tSimbolo tipoDato, char* id) {
  // Comprobamos que el id no esté usado ya
  idRepetida(id);
  insertarEntrada(funcion, id, tipoDato, 0, -1, NULL);
}

void insertarParametro(tSimbolo tipoDato, char* id) {
  // Comprobamos que no haya parámetros con nombres repetidos
  // Además guardamos el índice de la función
  int i;
  int parametroRepetido = 0;
  for (i = TOPE; !parametroRepetido && TS[i].entrada != funcion; --i) {
    if (!strcmp(TS[i].nombre, id)) {
      sprintf(msgError, "ERROR SEMANTICO: identificador del parámetro %s ya declarado\n", id);
      yyerror(msgError);
      parametroRepetido = 1;
    
    }
  }
  // Añadimos la entrada
  insertarEntrada(parametro_formal, id, tipoDato, -1, NONEDIM, NULL); // ********** una vez mas de dnd sacar la dimension ************
  // Actualizamos el nº de parámetros de la función
  ++TS[i].parametros;
}

void insertarDescriptor(char* etqEntrada, char* etqSalida, char* etqElse) {
  DescriptorDeInstrControl* descp = (DescriptorDeInstrControl*) malloc(sizeof(DescriptorDeInstrControl));
  descp->etiquetaEntrada = strdup(etqEntrada);
  descp->etiquetaSalida = strdup(etqSalida);
  descp->etiquetaElse = strdup(etqElse);
  insertarEntrada(descriptor, " ", -1, -1, -1, descp);
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
      sprintf(msgError, "ERROR SEMANTICO: se intenta asignar a %s, y no es una variable\n", id);
      yyerror(msgError);
    } else {
      if (esLista(TS[i].tipoDato)){
        if (ts == error || ts != listaATipo(TS[i].tipoDato)) {
          sprintf(msgError, "ERROR SEMANTICO: asignación incorrecta, %s es tipo %s y se obtuvo %s\n", id, tipoAString(TS[i].tipoDato), tipoAString(ts));
          yyerror(msgError);
        }
      }else{
        if (ts == error || ts != TS[i].tipoDato) {
          sprintf(msgError, "ERROR SEMANTICO2: asignación incorrecta, %s es tipo %s y se obtuvo %s\n", id, tipoAString(TS[i].tipoDato), tipoAString(ts));
          yyerror(msgError);
        }
      }
    }
    
  }
}

void isBooleana(tSimbolo ts) {
  if (ts == error || ts != booleano) {
    sprintf(msgError, "ERROR SEMANTICO: condición no es de tipo booleano, se tiene tipo %s", tipoAString(ts));
    yyerror(msgError);
  }
}

tSimbolo andLog(tSimbolo ts1, tSimbolo ts2) {
  if (ts1 == error || ts2 == error)
    return error;

  if (ts1 != booleano || ts2 != booleano) {
    sprintf(msgError, "ERROR SEMANTICO: operador and no aplicable a los tipos %s, %s\n", tipoAString(ts1), tipoAString(ts2));
    yyerror(msgError);
    return error;
  }

  return booleano;
}

tSimbolo orLog(tSimbolo ts1, tSimbolo ts2) {
  if (ts1 == error || ts2 == error)
    return error;

  if (ts1 != booleano || ts2 != booleano) {
    sprintf(msgError, "ERROR SEMANTICO: operador or no aplicable a los tipos %s, %s\n",   tipoAString(ts1), tipoAString(ts2));
    yyerror(msgError);
    return error;
  }

  return booleano;
}

tSimbolo eq(tSimbolo ts1, tSimbolo ts2) {
  if (ts1 == error || ts2 == error)
    return error;

  if (ts1 != ts2) {
    sprintf(msgError, "ERROR SEMANTICO: operador == no aplicable a los tipos %s, %s\n", tipoAString(ts1), tipoAString(ts2));
    yyerror(msgError);
    return error;
  }

  return booleano;
}
tSimbolo opBinario(tSimbolo ts1, int atr, tSimbolo ts2) { 
  if (ts1 == error || ts2 == error) return error; 

  if(esLista(ts1))
    ts1 = listaATipo(ts1);
  if(esLista(ts2))
    ts2 = listaATipo(ts2);
  
  switch(atr){ 
    case 0: // * 
      if(ts1 == entero && ts2 == entero) return entero; 
      else if(ts1 == real && ts2 == real) return real; 
      else{ 
        sprintf(msgError, "ERROR SEMANTICO: operador * no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
    break; 
    case 1: // / 
      if(ts1 == entero && ts2 == entero) return entero; 
      else if(ts1 == real && ts2 == real) return real; 
      else{ 
      sprintf(msgError, "ERROR SEMANTICO: operador / no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
      yyerror(msgError); 
      return error; 
      } 
    break; 
    case 2: // or 
      if(!(ts1 == booleano && ts2 == booleano)){
        sprintf(msgError, "ERROR SEMANTICO: operador or no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 3: // and 
      if(!(ts1 == booleano && ts2 == booleano)){
        sprintf(msgError, "ERROR SEMANTICO: operador and no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 4:// xor  
      if(!(ts1 == booleano && ts2 == booleano)){
        sprintf(msgError, "ERROR SEMANTICO: operador xor no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 5://  == 
      if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real)|| (ts1 == booleano && ts2 == booleano)|| (ts1 == caracter && ts2 == caracter)) ){
        sprintf(msgError, "ERROR SEMANTICO: operador == no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 6:// < 
      if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real))){
        sprintf(msgError, "ERROR SEMANTICO: operador < no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 7:// > 
     if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real))){
        sprintf(msgError, "ERROR SEMANTICO: operador > no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 8: // + 
      if(ts1 == entero && ts2 == entero) return entero; 
      else if(ts1 == real && ts2 == real) return real; 
      else{ 
      sprintf(msgError, "ERROR SEMANTICO: operador + no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
      yyerror(msgError); 
      return error; 
      } 
    break; 
    
  } 
}

void menosUnarioAplicable(tSimbolo ts){
  if(!(ts == entero || ts == real)){
    sprintf(msgError, "ERROR SEMANTICO: el operador - no es aplicable al tipo %s\n", tipoAString(ts));
    yyerror(msgError);
  }
}

void opUnarioAplicable(tSimbolo ts){
  if(ts != booleano){
    sprintf(msgError, "ERROR SEMANTICO: el operador not no es aplicable al tipo %s\n", tipoAString(ts));
    yyerror(msgError);
  }
}

void comprobarDimen(tSimbolo ts){
  if(!esEntero(ts)){
    sprintf(msgError, "ERROR SEMANTICO: el tipo %s no es válido como dimensión \n", tipoAString(ts));
    yyerror(msgError);
  }
}

void comprobarDevolver(tSimbolo ts){
  int i = TOPE;
  int marcaEncontrada = 0;
  int funcionEncontrada = 0;
  
  while (i >1 && (TS[i].entrada != funcion || TS[i].entrada == marca )) {
    
    --i;
  }
  
  
  if (i <= 0) {
    sprintf(msgError, "ERROR SEMANTICO: return no asignado a ninguna función, e i = %i \n",i);
    yyerror(msgError);
  } else if (ts != error && ts != TS[i].tipoDato && Subprog == 1) {
    sprintf(msgError, "ERROR SEMANTICO: return devuelve tipo %s, y función es de tipo %s\n",  tipoAString(ts), tipoAString(TS[i].tipoDato));
    yyerror(msgError);
  }
}

void comprobarArg(tSimbolo ts){
  
  if(TS[numArgs[1] + numArgs_llevados+1].tipoDato != ts)
    error_args=1;
  numArgs_llevados++;
}

void erroresArgs(){
  //numArgs_llevados++;
  if(numArgs[0]<numArgs_llevados ){
    sprintf(msgError, "ERROR SEMANTICO: Demasiados argumentos introducidos ");
    yyerror(msgError);

  }else if(numArgs[0]>numArgs_llevados){
    sprintf(msgError, "ERROR SEMANTICO: Pocos argumentos introducidos ");
    yyerror(msgError);
  }else if(numArgs[0]==numArgs_llevados && !error_args){

  }
  else if (error_args){
    sprintf(msgError, "ERROR SEMANTICO: tipo no se corresponde con los argumentos de la funcion \n");
    yyerror(msgError);
    }

  numArgs_llevados=0;
  error_args = 0;
}

tSimbolo tipoOp(tSimbolo ts, char * op) {
  if (!strcmp(op, "+") || !strcmp(op, "-") || !strcmp(op, "*") || !strcmp(op, "/"))
    return ts;

  if (!strcmp(op, "not") || !strcmp(op, "and") || !strcmp(op, "xor") || !strcmp(op, "or") || !strcmp(op, ">") || !strcmp(op, "<") || !strcmp(op, "=="))
    return booleano;

}

/* * Fin de funciones y procedimientos para manejo de la TS */

// *******  Generación código intermedio ******

int hayError = 0;
int deep = 0;
FILE * fMain;


#define addTab() { for (int i = 0; i < deep - (yyout != fMain); ++i) fprintf(yyout, "\t"); }
#define gen(f_, ...) { if (!hayError) {addTab(); fprintf(yyout, f_, ##__VA_ARGS__); fflush(yyout);} }

char* temporal() {
  static int indice = 1;
  char* temp = malloc(sizeof(char) * 10);
  sprintf(temp, "temp%i", indice++);
  return temp;
}

char* etiqueta() {
  static int indice = 1;
  char* etiqueta = malloc(sizeof(char) * 14);
  sprintf(etiqueta, "etiqueta%i", indice++);
  return etiqueta;
}

char* tipoIntermedio(tSimbolo ts) {
  if (esLista(ts))
    return "Lista";
  else if (ts == booleano)
    return "int";
  else
    return tipoAString(ts);
}

char* leerOp(tSimbolo ts1, char* exp1, char* op, char* exp2, tSimbolo ts2) {
  char* etiqueta = temporal();
  tSimbolo tsPrimario = ts1;
  char* expPrimaria = exp1;
  char* expSecundaria = exp2;
  /*if (esLista(ts2) && (!strcmp("+", op) || !strcmp("*", op))) {
    tsPrimario = ts2;
    expPrimaria = exp2;
    expSecundaria = exp1;
  }*/

  gen("%s %s;\n", tipoIntermedio(tipoOp(tsPrimario, op)), etiqueta);

  /*if (!strcmp("#", op)) {
    gen("%s = getTam(%s);\n", etiqueta, exp1);
  } else if (!strcmp("?", op)) {
    gen("%s = *(%s*)getActual(%s);\n", etiqueta, tipoIntermedio(aTipoLista(ts1)), exp1);
  } else if (!strcmp("@", op)) {
    gen("%s = *(%s*)get(%s, %s);\n", etiqueta, tipoIntermedio(aTipoLista(ts1)), exp1, exp2);
  } else if (!strcmp("--", op)) {
    gen("%s = borrarEn(%s, %s);\n", etiqueta, exp1, exp2);
  } else if (!strcmp("%", op)) {
    gen("%s = borrarAPartirDe(%s, %s);\n", etiqueta, exp1, exp2);
  } else if (!strcmp("**", op)) {
    gen("%s = concatenar(%s, %s);\n", etiqueta, exp1, exp2);
  } else if (esLista(tsPrimario)) {
    if (!strcmp("+", op)) {
      gen("%s = sumarLista(%s, %s);\n", etiqueta, expPrimaria, expSecundaria);
    } else if (!strcmp("-", op)) {
        gen("%s = restarLista(%s, %s);\n", etiqueta, expPrimaria, expSecundaria);
    } else if (!strcmp("*", op)) {
      gen("%s = multiplicarLista(%s, %s);\n", etiqueta, expPrimaria, expSecundaria);
    } else if (!strcmp("/", op)) {
      gen("%s = dividirLista(%s, %s);\n", etiqueta, expPrimaria, expSecundaria);
    }
  } else if (!strcmp("", exp2)) {
    gen("%s = %s %s;\n", etiqueta, op, exp1);
  } else {
    gen("%s = %s %s %s;\n", etiqueta, exp1, op, exp2);
  }*/ 
  return etiqueta;
}


char* leerCte(char* cte, tSimbolo ts) {
  if (ts == booleano) {
    if (!strcmp("verdadero", cte))
      return "1";
    else
      return "0";
  }
  return cte;
}

char* insertarDato(char* id, tSimbolo ts) {
  char* buffer = malloc(sizeof(char) * 100);
  switch (ts) {
    case entero:
    case booleano:
      sprintf(buffer, "pInt(%s)", id);
      return buffer;
    case real:
      sprintf(buffer, "pFloat(%s)", id);
      return buffer;
    case caracter:
      sprintf(buffer, "pChar(%s)", id);
      return buffer;
    default:
      if (!hayError) {
        sprintf(msgError, "ERROR INTERMEDIO: tipo no básico en insertarDato().\n");
        yyerror(msgError);
        exit(EXIT_FAILURE);
      }
  }
}

char* tipoImprimir(tSimbolo tipo) {
  if (tipo == entero)
    return "%d";
  else if (tipo == real)
    return "%f";
  else if (esLista(tipo) || tipo == booleano )
    return "%s";
  else if (tipo == caracter)
    return "%c";
  else {
    if (!hayError) {
      sprintf(msgError, "ERROR INTERMEDIO: tipoImprimir() tipo no válido.\n");
      yyerror(msgError);
      exit(EXIT_FAILURE);
    }
  }
}

char* inicializaTipoLista(tSimbolo tipo) {
  if (tipo == entero)
    return "tInt";
  else if (tipo == real)
    return "tFloat";
  else if (tipo == caracter)
    return "tChar";
  else if (tipo == booleano)
    return "tBool";
  else {
    if (!hayError) {
      sprintf(msgError, "ERROR INTERMEDIO: tipo no válido en inicializaTipoLista().\n");
      yyerror(msgError);
      exit(EXIT_FAILURE);
    }
  }
}


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
programa : PRINCIPAL {
              gen("#include <stdlib.h>\n");
              gen("#include <stdio.h>\n\n");
              gen("int main()\n");
            }
            inicio_de_bloque {insertarMarca(); }

inicio_de_bloque : LLAVEIZQ {gen("{\n");} bloque  

bloque : declar_de_variable_locales bloque
        | declar_de_fun bloque
        | sentencia bloque
        | sentencia_return LLAVEDER  {vaciarEntradas(); Subprog = 0;gen("}\n");}
        ;
    


declar_de_variable_locales :  TIPO  declaracion_v PYC    {gen("%s %s;\n", tipoIntermedio(tipoTmp), $2.codigo);}           
		| error IDEN
		| error PYC {yyerrok;}
		;
                
declaracion_v :   IDEN   {tipoTmp = $0.atrib; insertarVariable($1.lexema, NONEDIM); strcpy($$.codigo, $1.lexema);}
                | IDEN COMA declaracion_v  {tipoTmp = $0.atrib;insertarVariable($1.lexema, NONEDIM); sprintf($$.codigo, "%s, %s", $1.lexema, $3.codigo);}
                | IDEN ASIG expresion     {tipoTmp = $0.atrib; insertarVariable($1.lexema, NONEDIM); sprintf($$.codigo, "%s = %s", $1.lexema, $3.codigo);}
                ;

declar_de_fun : TIPO IDEN PARIZQ {insertarFuncion($1.atrib, $2.lexema); Subprog = 1;gen("%s %s (",tipoIntermedio($1.atrib), $3.lexema );} argumentos {insertarMarca();gen("%s)", $5.codigo);} PARDER inicio_de_bloque 
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



sentencia_asignacion : IDEN ASIG expresion PYC                     {comprobarAsignacion($1.lexema, $3.tipo);gen("%s = %s;\n", $1.lexema, $3.lexema);}
                      | iden_lista ASIG expresion PYC                 {comprobarAsignacion($1.lexema, $3.tipo);}
                      ;                                            


sentencia_if : CONDIF expresion LLAVEIZQ sentencias LLAVEDER                                          {isBooleana($2.tipo);}
            | CONDIF expresion LLAVEIZQ sentencias LLAVEDER CONDELSE LLAVEIZQ sentencias LLAVEDER     {isBooleana($2.tipo);}
            ;

sentencia_while : CONDWHILE PARIZQ expresion PARDER LLAVEIZQ sentencias LLAVEDER  {isBooleana($3.tipo);}

sentencia_entrada : ENTRADA PARIZQ IDEN PARDER PYC          {buscarEntrada($3.lexema);}

sentencia_salida : SALIDA PARIZQ lista_salida PARDER PYC ;            

sentencia_for : CONDFOR PARIZQ  sentencia_asignacion PYC expresion PYC sentencia_asignacion PARDER LLAVEIZQ sentencias LLAVEDER   {isBooleana($5.tipo);} 

sentencia_return : DEVOLVER IDEN PYC                {$2.tipo = buscarID($2.lexema); comprobarDevolver($2.tipo); gen("return %s;\n", $2.lexema);}
                | DEVOLVER CONS PYC                 {$2.tipo = tipoCons($2.lexema); comprobarDevolver($2.tipo); gen("return %s;\n", $2.lexema);}
                ;

llamada_func : IDEN PARIZQ {numArgs[0] = numeroArg($1.lexema);numArgs[1] = buscarEntrada($1.lexema);} argumentosLlamada PARDER PYC   {erroresArgs(); gen("llamada fun");}

lista_salida : lista_salida COMA cadena_expresion
            | cadena_expresion
            ;

cadena_expresion : expresion
                | CADENA
                ;

argumentos : TIPO IDEN COMA argumentos                                {insertarParametro($1.atrib, $2.lexema);sprintf($$.codigo, "%s %s, %s", tipoIntermedio($1.atrib), $2.lexema, $4.codigo);}
            | TIPO IDEN                                               {insertarParametro($1.atrib, $2.lexema);sprintf($$.codigo, "%s %s", tipoIntermedio($1.atrib), $2.lexema);}
            | error
            ;
          
argumentosLlamada : expresion COMA argumentosLlamada                  {comprobarArg($1.tipo);}
            | expresion                                               {comprobarArg($1.tipo);}
            | 
            ;



expresion    : expresion OPERADORBIN expresion                        {$$.tipo = opBinario($1.tipo, $2.atrib, $3.tipo); leerOp($1.tipo, $1.lexema, $2.lexema, $3.lexema, $3.tipo);}
            | IDEN                                                    {$$.tipo = buscarID($1.lexema); strcpy($$.codigo, $1.lexema);} 
            | CONS                                                    {$$.tipo = tipoCons($1.lexema); strcpy($$.codigo, leerCte($1.lexema, $1.tipo));}
            | MENOS CONS                                              {$$.tipo = tipoCons($2.lexema); menosUnarioAplicable($2.tipo);strcpy($$.codigo, leerCte($1.lexema, $1.tipo));}
            | PARIZQ expresion PARDER                                 {strcpy($$.codigo, $2.codigo); $$.tipo = $2.tipo;}
            | OPERADORUNARIO expresion                                {opUnarioAplicable($2.tipo);}
            | expresion MENOS expresion
            | llamada_func                                            {strcpy($$.lexema, $1.lexema); $$.tipo = $1.tipo;}
            | iden_lista
            | error
            ;

tipo_variable_complejo : TIPO LISTA CORIZQ CONS CORDER IDEN ASIG CORIZQ decl_tipo_comp CORDER PYC   {comprobarDimen(tipoCons($4.lexema));tipoTmp = aTipoLista($1.atrib); insertarVariable($6.lexema, atoi($4.lexema)); comprobarAsignacion($6.lexema, $9.tipo);}

                                                                                                      
iden_lista: IDEN CORIZQ CONS CORDER  {$$.tipo=aTipoLista($1.tipo);}

/*decl_tipo_comp : decl_tipo_comp_ent
            | decl_tipo_comp_real
            | decl_tipo_comp_booleano
            | decl_tipo_comp_lista
            | %empty
            ;*/

decl_tipo_comp : CONS COMA decl_tipo_comp                         {$$.tipo = tipoCons($1.lexema);}
                  | CONS                                          {$$.tipo = tipoCons($1.lexema);}
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
  fMain = fopen("prog.c", "w");

  yyout = fMain ;
  yyparse();

  fclose(fMain);

  return 0;
}