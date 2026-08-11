
from pyomo.environ import *
import numpy as np

# -------------------------- Input Data Example --------------------------
# Replace these with your actual data
B = ['model1', 'model2', 'model3']  # Example Aggregate ResStock models
Y = ['building1', 'building2']      # Example Aggregate AMI buildings
H = 24                               # Example hours in daily average

# Example modeled and aggregate AMI data per model-agrregate building(assuming like a single)-hour : Have added some random numbers need to get the real data flowing onto it
x_model = {(b, y, h): np.random.uniform(0, 10) for b in B for y in Y for h in range(1, H+1)}
x_ami = {(y, h): np.random.uniform(0, 10) for y in Y for h in range(1, H+1)}

# Peak average data, Currently I have put a random uniform value but in reality it has to come from the csv or restock and AMI dataset
p_c_model = {b: np.random.uniform(5, 15) for b in B}
p_h_model = {b: np.random.uniform(5, 15) for b in B}
p_c_ami = {y: np.random.uniform(5, 15) for y in Y}
p_h_ami = {y: np.random.uniform(5, 15) for y in Y}

# Penalty terms: previously 1 or 1000000 a very high number, currently I have put randomly, but penality comes from whether its in kmeans clusture and previously for n =or >10 then W=1 or very high value
w = {(b, y): np.random.uniform(1, 10) for b in B for y in Y}

# Weights need to be set or how are we planning to implement
alpha_c = 0.5
alpha_h = 0.5

# Minimum and maximum models to be selected per Aggregated AMI 
n = 1 # previosly it was 10 like in si 

# -------------------------- Pyomo Model --------------------------
model = ConcreteModel()

model.B = Set(initialize=B)
model.Y = Set(initialize=Y)

# Binary decision variables: 1 if model b selected for building y
#currently coded for a continuous but need to work on this part
model.X = Var(model.B, model.Y)

# RMSE term (pre-calculated outside optimization for simplicity)
def rmse_rule(model, b, y):
    return sqrt(sum((x_model[b, y, h] - x_ami[y, h]) ** 2 for h in range(1, H+1)) / H)

# Peak error terms
def pc_error(b, y):
    return abs(p_c_model[b] - p_c_ami[y])

def ph_error(b, y):
    return abs(p_h_model[b] - p_h_ami[y])

# Objective
def objective_rule(m):
    return sum(
        w[b, y] * m.X[b, y] + 
        alpha_c * pc_error(b, y) * m.X[b, y] +
        alpha_h * ph_error(b, y) * m.X[b, y] +
        rmse_rule(m, b, y) * m.X[b, y]
        for b in m.B for y in m.Y
    )
model.Objective = Objective(rule=objective_rule, sense=minimize)

# Constraints: at least and at most n models selected per group of building or aggregated AMI building

def max_models_rule(m, y):
    return sum(m.X[b, y] for b in m.B) 


model.MaxModels = Constraint(model.Y, rule=max_models_rule)

# -------------------------- Solve --------------------------
solver = SolverFactory('cbc')  # there is also gurobi, CPLEX
results = solver.solve(model, tee=True) # tee means to make the outputs observable

# -------------------------- Output --------------------------
for b in B:
    for y in Y:
        if model.X[b, y].value > 0.5:
            print(f"Selected model {b} for building {y}")
            print(b)