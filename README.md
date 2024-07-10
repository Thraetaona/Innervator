<div align="center">

  <h1><code>Innervator</code></h1>

  <p>
    <strong>Hardware Acceleration for Neural Networks</strong>
  </p>

  <h3>
    <a href="https://github.com/Thraetaona/Innervator/blob/main/docs/innervator_slides.pdf">Slides</a>
    <span> | </span>
    <a href="https://github.com/Thraetaona/Innervator/issues">Issue Tracker</a>
    <span> | </span>
    <a href="https://doi.org/10.5281/zenodo.12712832"><img src="https://zenodo.org/badge/DOI/10.5281/zenodo.12712832.svg" alt="DOI"></a>
  </h3>
  
</div>

***

## Abstract
Artificial intelligence ("AI") is deployed in various applications, from noise cancellation to image recognition.  AI-based products often come with high hardware and electricity costs, making them inaccessible for consumer devices and small-scale edge electronics.  Inspired by biological brains, deep neural networks ("DNNs") are modeled using mathematical formulae, but general-purpose processors treat otherwise-parallelizable AI algorithms as step-by-step sequential logic.  In contrast, programmable logic devices ("PLDs") can be customized to the specific parameters of a trained DNN, thereby ensuring data-tailored computation and algorithmic parallelism at the register-transfer level.  Furthermore, a subgroup of PLDs, field-programmable gate arrays ("FPGAs"), are dynamically reconfigurable.  So, to improve AI runtime performance, I designed and open-sourced my hardware compiler: Innervator.  Written entirely in VHDL-2008, Innervator takes any DNN's metadata and parameters (e.g., number of layers, neurons per layer, and their weights/biases), generating its synthesizable FPGA hardware description with the appropriate pipelining and batch processing; Innervator is entirely portable and vendor-independent.  As a proof of concept, I used Innervator to implement a sample 8x8-pixel handwritten digit-recognizing neural network in a low-cost AMD Xilinx Artix-7(TM) FPGA @ 100 MHz.  With 3 pipeline stages and 2 batches at about 60% area utilization, the Network achieved ~4.75 GOP/s, predicting the output in 630 ns and under 0.25 W of power.  In comparison, an Intel(R) Core(TM) i7-12700H CPU @ 4.70 GHz would take 40,000-60,000 ns at 45 to 115 W.  Ultimately, Innervator's hardware-accelerated approach bridges the inherent mismatch between current AI algorithms and the general-purpose digital hardware they run on.

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

Furthermore, these hardware-based neural networks could be named "Innervated Neural Networks," which also appears as INN in INNervator.

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

In the `./src/config.vhd` file, you will be able to fine-tune Innervator to your liking; almost everything is customizable and generic, down to the polarization/synchronization of reset, fixed-point types' widths, and neurons' batch processing size or pipeline stages.

## Hardware Demo (Arty A7-35T)

I used the four LEDs to "transmit" the network's prediction (i.e., resulting digit in this case); but the same UART interface could later be used to also transmit it back to the computer.

https://github.com/Thraetaona/Innervator/assets/42461518/52132598-aac0-4532-85c9-bce6e69aa214

##### (Note: The "delay" you see between the command prompt and FPGA is primarily due to the UART speed; the actual neural network itself takes ~1000 nanoseconds to process its input.)

## Simulation

![image](https://github.com/Thraetaona/Innervator/assets/42461518/d41b6820-9f31-438b-8ec8-4ff57709d11b)

##### (Note: This was an old simulation run; in the current version, the same digit was predicted with a %70+ accuracy.)

### The sample network that was used in said simulation:

![image](https://github.com/Thraetaona/Innervator/assets/42461518/209362d6-21fd-4f83-a357-e6855daa2485)

## Statistics (Arty A7-35T)

Including the periphals (e.g., UART, button debouncer, etc.) and given a network with an input and 2 neural layers (64 inputs, 20 hidden neurons, and 10 output neurons), 4 bits for integral and 4 bits for fractional widths of fixed-point numerals, no batch processing (one DSP for each neuron), and 3 pipeline stages; Innervator consumed the following resources:

|Resource|Utilization|Total Availability|
|:-|:-:|:-:|
| Logic LUT | 10233 | 20800|
| Sliced Reg. | 13954 | 41600 |
| F7 Mux. | 620 | 8150 |
| Slice | 3775 | 8150 |
| DSP | 30 | 90 |
| Bonded IOB | 7 | 210 |
| BUFGCTRL | 1 | 32 |

Timing reports were also great; the Worst Negative Slack (WNS) was *1.252 ns*, without aggressive synthesis optimizations, given a 100 MHz clock.  On the same FPGA, the number of giga-operations per second was *3 GOP/s*, and the total on-chip power draw was *0.189 W.*
