<div align="center">

  <h1><code>Innervator</code></h1>

  <p>
    <strong>Hardware Acceleration for Neural Networks</strong>
  </p>

  <h3>
    <a href="https://github.com/Thraetaona/Innervator/blob/main/docs/innervator_slides.pdf">Slides</a>
    <span> | </span>
    <a href="https://github.com/Thraetaona/Innervator/issues">Issue Tracker</a>
  </h3>
  
</div>

***

## Abstract
Artificial Intelligence ("AI") is deployed in various applications, ranging from noise cancellation to image recognition.  AI-based products often come at remarkably high hardware and electricity costs, making them inaccessible to consumer devices and small-scale edge electronics.  Inspired by biological brains, artificial neural networks are modeled in mathematical formulae and functions.  However, brains (i.e., analog systems) deal with continuous values along a spectrum (e.g., variance of voltage) rather than being restricted to the binary on/off states that digital hardware has; this continuous nature of analog logic allows for a smoother and more efficient representation of data.  Given how present computers are almost exclusively digital, they emulate analog-based AI algorithms in a space-inefficient and slow manner: a single analog value gets encoded as multitudes of binary digits on digital hardware.  In addition, general-purpose computer processors treat otherwise-parallelizable AI algorithms as step-by-step sequential logic.  So, in my research, I have explored the possibility of improving the state of AI performance on currently available mainstream digital hardware.  A family of digital circuitry known as Programmable Logic Devices ("PLDs") can be customized down to the specific parameters of a trained neural network, thereby ensuring data-tailored computation and algorithmic parallelism.  Furthermore, a subgroup of PLDs, the Field-Programmable Gate Arrays ("FPGAs"), are dynamically re-configurable; they are reusable and can have subsequent customized designs swapped out in-the-field.  As a proof of concept, I have implemented a sample 8x8-pixel handwritten digit-recognizing neural network, in a low-cost "Xilinx Artix-7" FPGA, using VHDL-2008 (a hardware description language by the U.S. DoD and IEEE).  Compared to software-emulated implementations, power consumption and execution speed were shown to have greatly improved; ultimately, this hardware-accelerated approach bridges the inherent mismatch between current AI algorithms and the general-purpose digital hardware they run on. 

## Notice
Although the Abstract specifically talks about an image-recognizing neural network, I endeavoured to generalize Innervator: in practice, it is capable of implementing any number of neurons and layers, and in any possible application (e.g., speech recognition), not just imagery.  In the `./data` folder, you will find weight and bias parameters that will be used during Innervator's synthesis.  Because of the incredibly broken implementation of VHDL's `std.textio` library across most synthesis tools, I was limited to only reading `std_logic_vector`s from files; due to that, weights and biases had to be pre-formatted in a fixed-point representation.  (More information is available in [`file_parser.vhd`](https://github.com/Thraetaona/Innervator/blob/main/src/neural/utils/file_parser.vhd).

The VHDL code itself has been very throughly documented; because I was a novice to VHDL, AI, and FPGA design myself, I documented each step as if it was a beginner's tutorial.  [Also, you may find these overview slides of the Project useful.](https://github.com/Thraetaona/Innervator/blob/main/docs/innervator_slides.pdf)

Interestingly, even though I was completely new to the world of hardware design, I still found the toolchain (and even VHDL itself) in a very unstable and buggy state; in fact, throughout this project, I found and documented dozens of different bugs, some of which were new and reported to IEEE and Xilinx:
* [VHDL Language Inconsistency in Ports](https://gitlab.com/IEEE-P1076/VHDL-Issues/-/issues/311)
* [VHDL Language Enhancement](https://gitlab.com/IEEE-P1076/VHDL-Issues/-/issues/312)
* [Bug in Vivado's `file_open()`](https://support.xilinx.com/s/question/0D54U00008CO8pTSAT/bug-fileopen-is-not-consistent-with-ieee-standards)
* [Bug in Vivado's `read()`](https://support.xilinx.com/s/question/0D54U00008ADvMRSA1/bug-in-vhdl-textioread-overload-of-real-datatypes-size-mismatch-in-assignment)

## Nomenclature
To innervate means "to supply something with nerves."

Innervator is, aptly, an implementer of *artificial neural networks* within *Programmable Logic Devices.*

## Foreword
* Prior to starting this project, I had no experience or training with artificial intelligence ("AI"), electrical engineering, or hardware design;
* Hardware design is a complex field&mdash;an "unlearn" of computer science; and
* Combining the two ideas, AI & hardware, transformed this project into a unique proof of concept.

## Synopsis
* Inspired by biological brains, AI neural networks are modeled in mathematical formulae that are inherently concurrent;
* AI applications are widespread but suffer from general-purpose computer processors that execute algorithms in step-by-step sequences; and
* Programmable Logic Devices ("PLDs") allow for digital circuitry to be predesigned for data-tailored and massively parallelized operations

## Build Instructions
[TODO: Create a TCL script and makefile to automate this.]

To ensure maximal compatibility, I tested Innervator across both Xilinx **Vivado 2024**'s synthesizer (not simulator) and Mentor Graphics **ModelSim 2016**'s simulator; the code itself was written using a subset of **VHDL-2008**, without any other language involved.  Additionally, absolutely **no vendor-specific libraries** were used in Innervator's design; only the official `std` and `IEEE` VHDL packages were utilized.

Because I developed Innervator on a small, entry-level FPGA board (i.e., Digilent Arty A7-35T), I faced many challenges in regard to logic resource usage and timing failures; however, this also ensured that Innervator would become very portable and resource-efficient.

## Simulation

![image](https://github.com/Thraetaona/Innervator/assets/42461518/d41b6820-9f31-438b-8ec8-4ff57709d11b)

##### (Note: This was an old simulation run; in the current version, the same digit was predicted with a %70+ accuracy.)

### The sample network that was used in said simulation:

![image](https://github.com/Thraetaona/Innervator/assets/42461518/209362d6-21fd-4f83-a357-e6855daa2485)
