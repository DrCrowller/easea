\TEMPLATE_START
/**
 This is program entry for CMAES template for EASEA

*/

\ANALYSE_PARAMETERS
#include <stdlib.h>
#include <iostream>
#include <time.h>
#include "COptionParser.h"
#include "CRandomGenerator.h"
#include "CEvolutionaryAlgorithm.h"
#include "global.h"
#include "EASEAIndividual.hpp"
#include "CCmaes.h"

using namespace std;

/** Global variables for the whole algorithm */
CIndividual** pPopulation = NULL;
CIndividual *bBest = NULL;
float* pEZ_MUT_PROB = NULL;
float* pEZ_XOVER_PROB = NULL;
unsigned *EZ_NB_GEN;
unsigned *EZ_current_generation;
int EZ_POP_SIZE;
int OFFSPRING_SIZE;

CEvolutionaryAlgorithm* EA;

CCmaes *cma;
//CMA cma;

int main(int argc, char** argv){


	parseArguments("EASEA.prm",argc,argv);
	ParametersImpl p;
	p.setDefaultParameters(argc,argv);
	CEvolutionaryAlgorithm* ea = p.newEvolutionaryAlgorithm();

	EA = ea;

	EASEAInit(argc,argv);

	CPopulation* pop = ea->getPopulation();

	ea->runEvolutionaryLoop();

	EASEAFinal(pop);

	delete pop;

	return 0;
}

\START_CUDA_GENOME_CU_TPL

#include <fstream>
#include <time.h>
#include <string>
#include <sstream>
#include "CRandomGenerator.h"
#include "CPopulation.h"
#include "COptionParser.h"
#include "CStoppingCriterion.h"
#include "CEvolutionaryAlgorithm.h"
#include "global.h"
#include "CIndividual.h"
#include "CCmaes.h"

using namespace std;
bool bReevaluate = false;

#include "EASEAIndividual.hpp"
bool INSTEAD_EVAL_STEP = false;

CRandomGenerator* globalRandomGenerator;
extern CEvolutionaryAlgorithm* EA;
#define STD_TPL

\INSERT_USER_DECLARATIONS
\ANALYSE_USER_CLASSES

\INSERT_USER_CLASSES

\INSERT_USER_FUNCTIONS

\INSERT_INITIALISATION_FUNCTION
\INSERT_FINALIZATION_FUNCTION

void evale_pop_chunk(CIndividual** population, int popSize){
  \INSTEAD_EVAL_FUNCTION
}

void EASEAInit(int argc, char** argv){
	\INSERT_INIT_FCT_CALL
  	cma = new CCmaes(setVariable("nbOffspring",\OFF_SIZE), setVariable("popSize",\POP_SIZE), \PROBLEM_DIM);
}

void EASEAFinal(CPopulation* pop){
	\INSERT_FINALIZATION_FCT_CALL;
	delete(cma);
}

void AESAEBeginningGenerationFunction(CEvolutionaryAlgorithm* evolutionaryAlgorithm){
    cma->cmaes_UpdateEigensystem(0);
    cma->TestMinStdDevs();
    \INSERT_BEGIN_GENERATION_FUNCTION
}

void AESAEEndGenerationFunction(CEvolutionaryAlgorithm* evolutionaryAlgorithm){
	\INSERT_END_GENERATION_FUNCTION
	evolutionaryAlgorithm->population->sortParentPopulation();
	double **popparent;
	double *fitpar;
	popparent = (double**)malloc(evolutionaryAlgorithm->population->parentPopulationSize*sizeof(double *));
	fitpar = (double*)malloc(evolutionaryAlgorithm->population->parentPopulationSize*sizeof(double));
	for(int i=0; i<(signed)evolutionaryAlgorithm->population->parentPopulationSize; i++)
		popparent[i] = (double*)malloc(\PROBLEM_DIM*sizeof(double));
	for(int i=0; i<(signed)evolutionaryAlgorithm->population->parentPopulationSize; i++){
		for(int j=0; j<\PROBLEM_DIM; j++){
			IndividualImpl *tmp = (IndividualImpl *)evolutionaryAlgorithm->population->parents[i];
			popparent[i][j] = tmp->\GENOME_NAME[j];
			//cout << popparent[i][j] << "|";
		}
		fitpar[i] = evolutionaryAlgorithm->population->parents[i]->fitness;
		//cout << fitpar[i] << endl;
	}
	cma->cmaes_update(popparent, fitpar);
	for(int i=0; i<(signed)evolutionaryAlgorithm->population->parentPopulationSize; i++){
		free(popparent[i]);
	}
	free(popparent);
	free(fitpar);

}

void AESAEGenerationFunctionBeforeReplacement(CEvolutionaryAlgorithm* evolutionaryAlgorithm){
        \INSERT_GENERATION_FUNCTION_BEFORE_REPLACEMENT
}



IndividualImpl::IndividualImpl() : CIndividual() {
  \GENOME_CTOR 
  for(int i=0; i<\PROBLEM_DIM; i++ ) {
	this->\GENOME_NAME[i] = 0.5 + (cma->sigma * cma->rgD[i] * cma->alea.alea_Gauss());
  }
  valid = false;
  isImmigrant = false;
}

CIndividual* IndividualImpl::clone(){
	return new IndividualImpl(*this);
}

IndividualImpl::~IndividualImpl(){
  \GENOME_DTOR
}


float IndividualImpl::evaluate(){
  if(valid)
    return fitness;
  else{
    valid = true;
    \INSERT_EVALUATOR
  }
}

void IndividualImpl::boundChecking(){
	\INSERT_BOUND_CHECKING
}

string IndividualImpl::serialize(){
    ostringstream AESAE_Line(ios_base::app);
    \GENOME_SERIAL
    AESAE_Line << this->fitness;
    return AESAE_Line.str();
}

void IndividualImpl::deserialize(string Line){
    istringstream AESAE_Line(Line);
    string line;
    \GENOME_DESERIAL
    AESAE_Line >> this->fitness;
    this->valid=true;
    this->isImmigrant=false;
}

IndividualImpl::IndividualImpl(const IndividualImpl& genome){

  // ********************
  // Problem specific part
  \COPY_CTOR


  // ********************
  // Generic part
  this->valid = genome.valid;
  this->fitness = genome.fitness;
  this->isImmigrant = false;
}


CIndividual* IndividualImpl::crossover(CIndividual** ps){
	// ********************
	// Generic part
	IndividualImpl** tmp = (IndividualImpl**)ps;
	IndividualImpl parent1(*this);
	IndividualImpl parent2(*tmp[0]);
	IndividualImpl child(*this);

	//DEBUG_PRT("Xover");
	/*   cout << "p1 : " << parent1 << endl; */
	/*   cout << "p2 : " << parent2 << endl; */

	// ********************
	// Problem specific part
  	for (int i = 0; i < \PROBLEM_DIM; ++i)
		cma->rgdTmp[i] = cma->rgD[i] * cma->alea.alea_Gauss();

	child.valid = false;
	/*   cout << "child : " << child << endl; */
	return new IndividualImpl(child);
}


void IndividualImpl::printOn(std::ostream& os) const{
	\INSERT_DISPLAY
}

std::ostream& operator << (std::ostream& O, const IndividualImpl& B)
{
  // ********************
  // Problem specific part
  O << "\nIndividualImpl : "<< std::endl;
  O << "\t\t\t";
  B.printOn(O);

  if( B.valid ) O << "\t\t\tfitness : " << B.fitness;
  else O << "fitness is not yet computed" << std::endl;
  return O;
}


unsigned IndividualImpl::mutate( float pMutationPerGene ){
  this->valid=false;


  // ********************
  // Problem specific part
  double sum;
  for (int i = 0; i < \PROBLEM_DIM; ++i) {
	sum = 0.;
	for (int j = 0; j < \PROBLEM_DIM; ++j)
		sum += cma->B[i][j] * cma->rgdTmp[j];
	this->\GENOME_NAME[i] = cma->rgxmean[i] + cma->sigma * sum;
  }
  return 0;
}




void ParametersImpl::setDefaultParameters(int argc, char** argv){

        this->minimizing =1;
        this->nbGen = setVariable("nbGen",(int)\NB_GEN);
	int nbCPUThreads = setVariable("nbCPUThreads", 1);
	omp_set_num_threads(nbCPUThreads);

        seed = setVariable("seed",(int)time(0));
        globalRandomGenerator = new CRandomGenerator(seed);
        this->randomGenerator = globalRandomGenerator;

        selectionOperator = getSelectionOperator(setVariable("selectionOperator","Tournament"), this->minimizing, globalRandomGenerator);
        replacementOperator = getSelectionOperator(setVariable("reduceFinalOperator","\RED_FINAL_OPERATOR"),this->minimizing, globalRandomGenerator);
        selectionPressure = 1;
        replacementPressure = setVariable("reduceFinalPressure",(float)\RED_FINAL_PRM);
        pCrossover = 1;
        pMutation = 1;
        pMutationPerGene = 1;

        parentPopulationSize = setVariable("popSize",(int)\POP_SIZE);
        offspringPopulationSize = setVariable("nbOffspring",(int)\OFF_SIZE);

        this->elitSize = 0;

	offspringReduction = parentReduction = false;

        generationalCriterion = new CGenerationalCriterion(setVariable("nbGen",(int)\NB_GEN));
        controlCStopingCriterion = new CControlCStopingCriterion();
        timeCriterion = new CTimeCriterion(setVariable("timeLimit",\TIME_LIMIT));

	this->optimise = 0;

        this->printStats = setVariable("printStats",\PRINT_STATS);
        this->generateCSVFile = setVariable("generateCSVFile",\GENERATE_CSV_FILE);
        this->generatePlotScript = setVariable("generatePlotScript",\GENERATE_GNUPLOT_SCRIPT);
        this->generateRScript = setVariable("generateRScript",\GENERATE_R_SCRIPT);
        this->plotStats = setVariable("plotStats",\PLOT_STATS);
        this->printInitialPopulation = setVariable("printInitialPopulation",0);
        this->printFinalPopulation = setVariable("printFinalPopulation",0);
        this->savePopulation = setVariable("savePopulation",\SAVE_POPULATION);
        this->startFromFile = setVariable("startFromFile",\START_FROM_FILE);

        this->outputFilename = (char*)"EASEA";
        this->plotOutputFilename = (char*)"EASEA.png";

        this->remoteIslandModel = setVariable("remoteIslandModel",\REMOTE_ISLAND_MODEL);
        this->ipFile = (char*)setVariable("ipFile","\IP_FILE").c_str();
        this->migrationProbability = setVariable("migrationProbability",(float)\MIGRATION_PROBABILITY);
        this->serverPort - setVariable("serverPort",\SERVER_PORT);
}

CEvolutionaryAlgorithm* ParametersImpl::newEvolutionaryAlgorithm(){

	pEZ_MUT_PROB = &pMutationPerGene;
	pEZ_XOVER_PROB = &pCrossover;
	EZ_NB_GEN = (unsigned*)setVariable("nbGen",\NB_GEN);
	EZ_current_generation=0;
	EZ_POP_SIZE = parentPopulationSize;
	OFFSPRING_SIZE = offspringPopulationSize;

	CEvolutionaryAlgorithm* ea = new EvolutionaryAlgorithmImpl(this);
	generationalCriterion->setCounterEa(ea->getCurrentGenerationPtr());
	 ea->addStoppingCriterion(generationalCriterion);
	ea->addStoppingCriterion(controlCStopingCriterion);
	ea->addStoppingCriterion(timeCriterion);

	  EZ_NB_GEN=((CGenerationalCriterion*)ea->stoppingCriteria[0])->getGenerationalLimit();
	  EZ_current_generation=&(ea->currentGeneration);

	 return ea;
}

void EvolutionaryAlgorithmImpl::initializeParentPopulation(){
        if(this->params->startFromFile){
          ifstream AESAE_File("EASEA.pop");
          string AESAE_Line;
          for( unsigned int i=0 ; i< this->params->parentPopulationSize ; i++){
                  getline(AESAE_File, AESAE_Line);
                  this->population->addIndividualParentPopulation(new IndividualImpl(),i);
                  ((IndividualImpl*)this->population->parents[i])->deserialize(AESAE_Line);
          }

        }
        else{
          for( unsigned int i=0 ; i< this->params->parentPopulationSize ; i++){
                  this->population->addIndividualParentPopulation(new IndividualImpl(),i);
          }
        }
        this->population->actualParentPopulationSize = this->params->parentPopulationSize;
}


EvolutionaryAlgorithmImpl::EvolutionaryAlgorithmImpl(Parameters* params) : CEvolutionaryAlgorithm(params){
	;
}

EvolutionaryAlgorithmImpl::~EvolutionaryAlgorithmImpl(){

}

\START_CUDA_GENOME_H_TPL

#ifndef PROBLEM_DEP_H
#define PROBLEM_DEP_H

//#include "CRandomGenerator.h"
#include <stdlib.h>
#include <iostream>
#include <string>
#include <CIndividual.h>
#include <Parameters.h>
#include <CCmaes.h>

using namespace std;

class CRandomGenerator;
class CSelectionOperator;
class CGenerationalCriterion;
class CEvolutionaryAlgorithm;
class CPopulation;
class CCmaes;
class Parameters;

extern int EZ_POP_SIZE;
extern int OFFSPRING_SIZE;

extern CCmaes *cma;

\INSERT_USER_CLASSES_DEFINITIONS

class IndividualImpl : public CIndividual {

public: // in EASEA the genome is public (for user functions,...)
	// Class members
  	\INSERT_GENOME


public:
	IndividualImpl();
	IndividualImpl(const IndividualImpl& indiv);
	virtual ~IndividualImpl();
	float evaluate();
	static unsigned getCrossoverArrity(){ return 2; }
	float getFitness(){ return this->fitness; }
	CIndividual* crossover(CIndividual** p2);
	void printOn(std::ostream& O) const;
	CIndividual* clone();

	unsigned mutate(float pMutationPerGene);

	void boundChecking();

        string serialize();
        void deserialize(string AESAE_Line);

	friend std::ostream& operator << (std::ostream& O, const IndividualImpl& B) ;
	void initRandomGenerator(CRandomGenerator* rg){ IndividualImpl::rg = rg;}

};


class ParametersImpl : public Parameters {
public:
	void setDefaultParameters(int argc, char** argv);
	CEvolutionaryAlgorithm* newEvolutionaryAlgorithm();
};

/**
 * @TODO ces functions devraient s'appeler weierstrassInit, weierstrassFinal etc... (en gros EASEAFinal dans le tpl).
 *
 */

void EASEAInit(int argc, char** argv);
void EASEAFinal(CPopulation* pop);
void EASEABeginningGenerationFunction(CEvolutionaryAlgorithm* evolutionaryAlgorithm);
void EASEAEndGenerationFunction(CEvolutionaryAlgorithm* evolutionaryAlgorithm);
void EASEAGenerationFunctionBeforeReplacement(CEvolutionaryAlgorithm* evolutionaryAlgorithm);


class EvolutionaryAlgorithmImpl: public CEvolutionaryAlgorithm {
public:
	EvolutionaryAlgorithmImpl(Parameters* params);
	virtual ~EvolutionaryAlgorithmImpl();
	void initializeParentPopulation();
};

#endif /* PROBLEM_DEP_H */

\START_CUDA_MAKEFILE_TPL

UNAME := $(shell uname)

ifeq ($(shell uname -o 2>/dev/null),Msys)
	OS := MINGW
endif

ifneq ("$(OS)","")
	EZ_PATH=../../
endif

EASEALIB_PATH=$(EZ_PATH)libeasea/

CXXFLAGS =  -std=c++14 -fopenmp -O2 -g -Wall -fmessage-length=0 -I$(EASEALIB_PATH)include 

OBJS = EASEA.o EASEAIndividual.o 

LIBS = -lpthread -fopenmp
ifneq ("$(OS)","")
	LIBS += -lws2_32 -lwinmm -L"C:\MinGW\lib"
endif

\INSERT_MAKEFILE_OPTION

#USER MAKEFILE OPTIONS :
\INSERT_MAKEFILE_OPTION#END OF USER MAKEFILE OPTIONS

TARGET =	EASEA

$(TARGET):	$(OBJS)
	$(CXX) -o $(TARGET) $(OBJS) $(LDFLAGS) -g $(EASEALIB_PATH)libeasea.a $(LIBS)

	
#%.o:%.cpp
#	$(CXX) -c $(CXXFLAGS) $^

all:	$(TARGET)
clean:
ifneq ("$(OS)","")
	-del $(OBJS) $(TARGET).exe
else
	rm -f $(OBJS) $(TARGET)
endif
easeaclean:
ifneq ("$(OS)","")
	rm -f $(TARGET).exe *.o *.cpp *.hpp EASEA.png EASEA.dat EASEA.prm EASEA.mak Makefile EASEA.vcproj EASEA.r EASEA.plot EASEA.csv EASEA.plo EASEA.pop
else
	-del $(TARGET) *.o *.cpp *.hpp EASEA.png EASEA.dat EASEA.prm EASEA.mak Makefile EASEA.vcproj EASEA.r EASEA.plot EASEA.csv EASEA.plo EASEA.pop
endif
	

\START_EO_PARAM_TPL#****************************************
#
#  EASEA.prm
#
#  Parameter file generated by CMAES.tpl AESAE v0.1
#
#***************************************
# --seed=0   # -S : Random number seed. It is possible to give a specific seed.

######    Evolution Engine    ######
--popSize=\POP_SIZE # -P : Population Size
--nbOffspring=\OFF_SIZE # -O : Nb of offspring (percentage or absolute)

######    Stopping Criterions    #####
--nbGen=\NB_GEN #Nb of generations
--timeLimit=\TIME_LIMIT # Time Limit: desactivate with (0) (in Seconds)

######    Evolution Engine / Replacement    ######
--elite=\ELITE_SIZE  # Nb of elite parents (absolute)
--eliteType=\ELITISM # Strong (1) or weak (0) elitism (set elite to 0 for none)
--reduceFinalOperator=\RED_FINAL_OPERATOR
--reduceFinalPressure=\RED_FINAL_PRM

#####   Stats Ouput     #####
--printStats=\PRINT_STATS #print Stats to screen
--plotStats=\PLOT_STATS #plot Stats 
--printInitialPopulation=0 #Print initial population
--printFinalPopulation=0 #Print final population
--generateCSVFile=\GENERATE_CSV_FILE
--generatePlotScript=\GENERATE_GNUPLOT_SCRIPT
--generateRScript=\GENERATE_R_SCRIPT

#### Population save    ####
--savePopulation=\SAVE_POPULATION #save population to EASEA.pop file
--startFromFile=\START_FROM_FILE #start optimisation from EASEA.pop file

#### Remote Island Model ####
--remoteIslandModel=\REMOTE_ISLAND_MODEL #To initialize communications with remote AESAE's
--ipFile=\IP_FILE
--migrationProbability=\MIGRATION_PROBABILITY #Probability to send an individual every generation
--serverPort=\SERVER_PORT
\TEMPLATE_END
