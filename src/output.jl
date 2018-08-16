function output_ini(u,v,η)
    # initialises netcdf files for data output

    if output == 1

        # Dimensions
        xudim = NcDim("x",nux,values=x_u)
        yudim = NcDim("y",nuy,values=y_u)
        xvdim = NcDim("x",nvx,values=x_v)
        yvdim = NcDim("y",nvy,values=y_v)
        xTdim = NcDim("x",nx,values=x_T)
        yTdim = NcDim("y",ny,values=y_T)
        tdim = NcDim("t",0,unlimited=true)

        # Variables
        uvar = NcVar("u",[xudim,yudim,tdim],t=Float32)
        vvar = NcVar("v",[xvdim,yvdim,tdim],t=Float32)
        ηvar = NcVar("eta",[xTdim,yTdim,tdim],t=Float32)

        # current bug in NetCDF package - tvar has to be defined for every variable separately
        tvaru = NcVar("t",tdim,t=Int64)
        tvarv = NcVar("t",tdim,t=Int64)
        tvarη = NcVar("t",tdim,t=Int64)

        ncu = NetCDF.create(runpath*"u.nc",[uvar,tvaru],mode=NC_NETCDF4)
        ncv = NetCDF.create(runpath*"v.nc",[vvar,tvarv],mode=NC_NETCDF4)
        ncη = NetCDF.create(runpath*"eta.nc",[ηvar,tvarη],mode=NC_NETCDF4)

        # Attributes
        Dictu = Dict{String,Any}("description"=>"Data from shallow-water model juls.")
        Dictu["details"] = "Cartesian coordinates, f or beta-plane, Arakawa C-grid"
        Dictu["reference"] = "github.com/milankl/juls"
        Dictu["cfl"] = cfl
        Dictu["g"] = gravity
        Dictu["water_depth"] = water_depth
        Dictu["bc_x"] = bc_x
        Dictu["lbc"] = lbc
        Dictu["drag"] = drag
        Dictu["c_smag"] = c_smag
        Dictu["initial_cond"] = initial_cond
        Dictu["init_run_id"] = init_run_id
        Dictu["phi"] = ϕ
        Dictu["seamount_height"] = seamount_height
        Dictu["Numtype"] = string(Numtype)
        Dictu["output_dt"] = nout*dtint

        # Write attributes and units
        for nc in (ncu,ncv,ncη)
            NetCDF.putatt(nc,"global",Dictu)
            NetCDF.putatt(nc,"t",Dict("units"=>"s","long_name"=>"time"))
            NetCDF.putatt(nc,"x",Dict("units"=>"m","long_name"=>"zonal coordinate"))
            NetCDF.putatt(nc,"y",Dict("units"=>"m","long_name"=>"meridional coordinate"))
        end

        NetCDF.putatt(ncu,"u",Dict("units"=>"m/s","long_name"=>"zonal velocity"))
        NetCDF.putatt(ncv,"v",Dict("units"=>"m/s","long_name"=>"meridional velocity"))
        NetCDF.putatt(ncη,"eta",Dict("units"=>"m","long_name"=>"sea surface height"))

        # write initial conditions
        iout = 1   # counter for output time steps
        ncs = (ncu,ncv,ncη)
        ncs,iout = output_nc(ncs,u,v,η,0,iout)

        # also output scripts
        scripts_output()

        return ncs,iout
    else
        return nothing, nothing
    end
end

function output_nc(ncs,u,v,η,i,iout)
    # write data output to netcdf

    if i % nout == 0 && output == 1     # output only every nout time steps

        # cut off the halo
        NetCDF.putvar(ncs[1],"u",Float32.(u[halo+1:end-halo,halo+1:end-halo]),start=[1,1,iout],count=[-1,-1,1])
        NetCDF.putvar(ncs[2],"v",Float32.(v[halo+1:end-halo,halo+1:end-halo]),start=[1,1,iout],count=[-1,-1,1])
        NetCDF.putvar(ncs[3],"eta",Float32.(η[haloη+1:end-haloη,haloη+1:end-haloη]),start=[1,1,iout],count=[-1,-1,1])

        for nc in ncs
                NetCDF.putvar(nc,"t",Int64[i*dtint],start=[iout])
                NetCDF.sync(nc)     # sync to view netcdf while model is still running
        end

        iout += 1
    end

    return ncs,iout
end

function output_close(ncs,progrtxt)
    # finalise netcdf files
    if output == 1
        for nc in ncs
            NetCDF.close(nc)
        end
        println("All data stored.")
        write(progrtxt,"All data stored.")
        close(progrtxt)
    end
end

function get_run_id_path()
    # check output folders to determine a 4-digit run id number

    if output == 1
        runlist = filter(x->startswith(x,"run"),readdir(outpath))
        existing_runs = [parse(Int,id[4:end]) for id in runlist]
        if length(existing_runs) == 0           # if no runfolder exists yet
            runpath = outpath*"run0000/"
            mkdir(runpath)
            return 0,runpath
        else                                    # create next folder
            run_id = maximum(existing_runs)+1
            runpath = outpath*"run"*@sprintf("%04d",run_id)*"/"
            mkdir(runpath)
            return run_id,runpath
        end
    else
        return 0,"no runpath"
    end
end

function scripts_output()
    # archives all .jl files of juls in the output folder to make runs reproducible

    if output == 1
        # copy all files in juls main folder
        mkdir(runpath*"scripts")
        for juliafile in filter(x->endswith(x,".jl"),readdir())
            cp(juliafile,runpath*"scripts/"*juliafile)
        end

        # and also in the src folder
        mkdir(runpath*"scripts/src")
        for juliafile in filter(x->endswith(x,".jl"),readdir("src"))
            cp("src/"*juliafile,runpath*"scripts/src/"*juliafile)
        end
    end
end

# get the run id number and create folders
const run_id,runpath = get_run_id_path()
