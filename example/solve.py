import scopf


BUS_FILE_PATH = "./data/IEEE14.bus"
LINE_FILE_PATH = "./data/IEEE14.line"
CONTINGENCY_FILE_PATH = "./data/IEEE14.contingency"
GENERATOR_COST_FILE_PATH = "./data/IEEE14.cost"

scopf.solve_scopf_problem(
    BUS_FILE_PATH, LINE_FILE_PATH, GENERATOR_COST_FILE_PATH, CONTINGENCY_FILE_PATH
)

