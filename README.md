# yolov8-trt-examples
## 1. Environment for Build
ubuntu18.06 ubuntu 64位, CUDA = 11.3, TensorRT = 8.4.1.5, opencv >= 4 , 1080TI  
## 2. Export Engine by Trtexec Tools
TensorRT-8.4.1.5/bin/trtexec --onnx=yolov8s.onnx --saveEngine=yolov8s.engine --fp16  
## 3. Build Project
cd yolov8-trt-examples    
make pro  
## 4. Run project
cd workspace  
./pro  
