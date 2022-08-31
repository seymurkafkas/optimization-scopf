# Security Constrained Linear Optimal Power Flow

## Features
- Load a bus file in the model file that matches the data signature (.bus)
- Load a line file in the model file that matches the data signature (.line)
- Load generator cost data (quadratic costs are assumed) (.cost)
- Load contingency data (possible line contingencies)  (.contingency)

## Installation
A demo or commercial version of AMPL is required to use the API.

Install the required packages with 
```sh
pip install -r requirements.txt
```

Install this package (preferably in editable mode)

```sh
pip install -e .
```

## Usage
Declare your bus, line, possible contingency, generator cost data. Use the schema declared in the example directory.

Call the solve_scopf_problem() function with the file path parameters.

For example, 
```
BUS_FILE_PATH = "./data/IEEE14.bus"
LINE_FILE_PATH = "./data/IEEE14.line"
CONTINGENCY_FILE_PATH = "./data/IEEE14.contingency"
GENERATOR_COST_FILE_PATH = "./data/IEEE14.cost"

scopf.solve_scopf_problem(BUS_FILE_PATH, LINE_FILE_PATH, GENERATOR_COST_FILE_PATH, CONTINGENCY_FILE_PATH)
```

 AN AMPL instance will be created to solve the problem. The regular and contingency flow results are written to stdout.
