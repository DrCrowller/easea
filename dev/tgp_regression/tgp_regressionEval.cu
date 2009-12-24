#define NUMTHREAD2 128
#define MAX_STACK 50
#define LOGNUMTHREAD2 7

#define HIT_LEVEL  0.01f
#define PROBABLY_ZERO  1.11E-15f
#define BIG_NUMBER 1.0E15f


__global__ static void 
EvaluatePostFixIndividuals_128(const float * k_progs,
			       const int maxprogssize,
			       const int popsize,
			       const float * k_inputs,
			       const float * k_outputs,
			       const int trainingSetSize,
			       float * k_results,
			       int *k_hits,
			       int* k_indexes
			       )
{
  __shared__ float tmpresult[NUMTHREAD2];
  __shared__ float tmphits[NUMTHREAD2];
  
  const int tid = threadIdx.x; //0 to NUM_THREADS-1
  const int bid = blockIdx.x; // 0 to NUM_BLOCKS-1

  
  int index;   // index of the prog processed by the block 
  float sum = 0.0;
  int hits = 0 ; // hits number

  float currentX, currentOutput;
  float result;
  int start_prog;
  int codop;
  float stack[MAX_STACK];
  int  sp;
  float op1, op2;
  float tmp;

  index = bid; // one program per block => block ID = program number
 
  if (index >= popsize) // idle block (should never occur)
    return;
  if (k_progs[index] == -1.0) // already evaluated
    return;

  // Here, it's a busy thread

  sum = 0.0;
  hits = 0 ; // hits number
  
  // Loop on training cases, per cluster of 32 cases (= number of thread)
  // (even if there are only 8 stream processors, we must spawn at least 32 threads) 
  // We loop from 0 to upper bound INCLUDED in case trainingSetSize is not 
  // a multiple of NUMTHREAD
  for (int i=0; i < ((trainingSetSize-1)>>LOGNUMTHREAD2)+1; i++) {
    
    // are we on a busy thread?
    if (i*NUMTHREAD2+tid >= trainingSetSize) // no!
      continue;

    currentX = k_inputs[i*NUMTHREAD2+tid];
    currentOutput = k_outputs[i*NUMTHREAD2+tid];

    start_prog = k_indexes[index]; // index of first codop
    codop =  k_progs[start_prog++];
    
    sp = 0; // stack and stack pointer
    
    while (codop != OP_RETURN){
      switch(codop)
	{
	case OP_W :
	  stack[sp++] = currentX;
	  break;
	case OP_ERC:
	  tmp =  k_progs[start_prog++];
	  stack[sp++] = tmp;
	  break;
	case OP_MUL :
	  sp--;
	  op1 = stack[sp];
	  sp--;
	  op2 = stack[sp];
	  stack[sp] = __fmul_rz(op1, op2);
	  stack[sp] = op1*op2;
	  sp++;
	  break;
	case OP_ADD :
	  sp--;
	  op1 = stack[sp];
	  sp--;
	  op2 = stack[sp];
	  stack[sp] = __fadd_rz(op1, op2);
	  stack[sp] = op1+op2;
	  sp++;
	  break;
	case OP_SUB :
	  sp--;
	  op1 = stack[sp];
	  sp--;
	  op2 = stack[sp];
	  stack[sp] = op2 - op1;
	  sp++;
	  break;
	case OP_DIV :
	  sp--;
	  op2 = stack[sp];
	  sp--;
	  op1 = stack[sp];
	  if (op2 == 0.0)
	    stack[sp] = 1.0;
	  else
	    stack[sp] = op1/op2;
	  sp++;
	  break;
	}
      // get next codop
      codop =  k_progs[start_prog++];
    } // codop interpret loop
    
    result = fabsf(stack[0] - currentOutput);
    
    if (!(result < BIG_NUMBER))
      result = BIG_NUMBER;
    else if (result < PROBABLY_ZERO)
      result = 0.0;
    
    if (result <= HIT_LEVEL)
      hits++;
    
    sum += result; // sum raw error on all training cases
    
  } // LOOP ON TRAINING CASES
  
  // gather results from all threads => we need to synchronize
  tmpresult[tid] = sum;
  tmphits[tid] = hits;
  __syncthreads();

  if (tid == 0) {
    for (int i = 1; i < NUMTHREAD2; i++) {
      tmpresult[0] += tmpresult[i];
      tmphits[0] += tmphits[i];
    }    
    k_results[index] = tmpresult[0];
    k_hits[index] = tmphits[0];
  }  
  // here results and hits have been stored in their respective array: we can leave
}