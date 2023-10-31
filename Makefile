cc        := g++


LOCAL_DIR	:= $(shell pwd)
# $(info "[LOCAL_DIR]: $(LOCAL_DIR)") 

lean_protobuf  := $(LOCAL_DIR)/lean/protobuf-3.11.4/build
lean_tensor_rt := $(LOCAL_DIR)/lean/TensorRT-8.4.1.5
lean_cudnn     := /usr/local/cuda-11.3
lean_opencv    := $(LOCAL_DIR)/lean/opencv-4
lean_cuda      := /usr/local/cuda-11.3

nvcc      = ${lean_cuda}/bin/nvcc


cuda_arch := -gencode=arch=compute_61,code=sm_61

cpp_srcs  := $(shell find src -name "*.cpp")
cpp_objs  := $(cpp_srcs:.cpp=.cpp.o)
cpp_objs  := $(cpp_objs:src/%=objs/%)
cpp_mk    := $(cpp_objs:.cpp.o=.cpp.mk)

cu_srcs  := $(shell find src -name "*.cu")
cu_objs  := $(cu_srcs:.cu=.cu.o)
cu_objs  := $(cu_objs:src/%=objs/%)
cu_mk    := $(cu_objs:.cu.o=.cu.mk)

include_paths := src        \
			src/yolov8_app \
			src/tensorRT	\
			src/tensorRT/common  \
			$(lean_protobuf)/include \
			$(lean_opencv)/include    \
			$(lean_tensor_rt)/include \
			$(lean_cuda)/include  \
			$(lean_cudnn)/include 

library_paths := $(lean_protobuf)/lib \
			$(lean_opencv)/lib    \
			$(lean_tensor_rt)/lib \
			$(lean_cuda)/lib64/stubs  \
			$(lean_cudnn)/lib64

link_librarys := opencv_core opencv_imgproc opencv_videoio opencv_imgcodecs opencv_dnn opencv_highgui \
			nvinfer nvinfer_plugin \
			cuda cublas cudart cudnn \
			stdc++ protobuf dl


# HAS_PYTHON表示是否编译python支持
support_define    := 

ifeq ($(use_python), true) 
include_paths  += $(python_root)/include/$(python_name)
library_paths  += $(python_root)/lib
link_librarys  += $(python_name)
support_define += -DHAS_PYTHON
endif

empty         :=
export_path   := $(subst $(empty) $(empty),:,$(library_paths))

run_paths     := $(foreach item,$(library_paths),-Wl,-rpath=$(item))
include_paths := $(foreach item,$(include_paths),-I$(item))
library_paths := $(foreach item,$(library_paths),-L$(item))
link_librarys := $(foreach item,$(link_librarys),-l$(item))

cpp_compile_flags := -std=c++11 -g -w -O0 -fPIC -pthread -fopenmp $(support_define)
cu_compile_flags  := -std=c++11 -g -w -O0 -Xcompiler "$(cpp_compile_flags)" $(cuda_arch) $(support_define)
link_flags        := -pthread -fopenmp -Wl,-rpath='$$ORIGIN'

cpp_compile_flags += $(include_paths)
cu_compile_flags  += $(include_paths)
link_flags        += $(library_paths) $(link_librarys) $(run_paths)

ifneq ($(MAKECMDGOALS), clean)
-include $(cpp_mk) $(cu_mk)
endif

pro    : workspace/pro
pytrtc : example-python/pytrt/libpytrtc.so
expath : library_path.txt

library_path.txt : 
	@echo LD_LIBRARY_PATH=$(export_path):"$$"LD_LIBRARY_PATH > $@

workspace/pro : $(cpp_objs) $(cu_objs)
	@echo Link $@
	@mkdir -p $(dir $@)
	@$(cc) $^ -o $@ $(link_flags)

example-python/pytrt/libpytrtc.so : $(cpp_objs) $(cu_objs)
	@echo Link $@
	@mkdir -p $(dir $@)
	@$(cc) -shared $^ -o $@ $(link_flags)

objs/%.cpp.o : src/%.cpp
	@echo Compile CXX $<
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@ $(cpp_compile_flags)
#  @echo @$(cc) -c $< -o $@ $(cpp_compile_flags)

objs/%.cu.o : src/%.cu
	@echo Compile CUDA $<
	@mkdir -p $(dir $@)
	@$(nvcc) -c $< -o $@ $(cu_compile_flags)

objs/%.cpp.mk : src/%.cpp
	@echo Compile depends CXX $<
	@mkdir -p $(dir $@)
	@$(cc) -M $< -MF $@ -MT $(@:.cpp.mk=.cpp.o) $(cpp_compile_flags)
	
objs/%.cu.mk : src/%.cu
	@echo Compile depends CUDA $<
	@mkdir -p $(dir $@)
	@$(nvcc) -M $< -MF $@ -MT $(@:.cu.mk=.cu.o) $(cu_compile_flags)

clean :
	@rm -rf objs workspace/pro example-python/pytrt/libpytrtc.so example-python/build example-python/dist example-python/pytrt.egg-info example-python/pytrt/__pycache__
	@rm -rf build
	@rm -rf example-python/pytrt/libplugin_list.so
	@rm -rf library_path.txt

.PHONY : clean yolo alphapose fall debug

# 导出符号，使得运行时能够链接上
export LD_LIBRARY_PATH:=$(export_path):$(LD_LIBRARY_PATH)
