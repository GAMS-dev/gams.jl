Sets
   model_types / system.ModelTypes /
   solvers / system.SolverNames /
   platforms / system.Platforms /
   components / system.Components /
   map_solver_type_platform(solvers,model_types,platforms) / system.SolverTypePlatformMap /
   map_component_solver(components,solvers) / system.ComponentSolverMap /
   real_solvers(solvers)
   map_components_solvers_licensed(components,solvers)
   licensed_solvers(solvers)
   supported(solvers,model_types);

real_solvers(solvers) = sum(model_types,SolverCapabilities(solvers,model_types));
map_components_solvers_licensed(components,real_solvers)$(ComponentMDate(components)*map_component_solver(components,real_solvers)) = yes;
licensed_solvers(real_solvers) = sum(map_components_solvers_licensed(components,real_solvers), 1);
supported(licensed_solvers,model_types)$map_solver_type_platform(licensed_solvers,model_types,'%system.platform%') = yes;

execute_unload 'solver_info.gdx' supported;
