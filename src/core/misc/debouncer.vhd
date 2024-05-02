-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- debouncer.vhd is a part of Innervator.
-- --------------------------------------------------------------------


-- Background: When you press a physical button, the metal contacts
-- don't make a perfect, clean contact instantly; instead, they might
-- "bounce" against each other several times, over a few milliseconds,
-- before settling into a closed state.  Additionally, Microcontrollers
-- and FPGAs are incredibly fast, and they can detect each of those
-- tiny bounces as if they were separate button presses; this could
-- lead to a single button press being interpreted as multiple presses.
--     There are many ways to resolve this matter, and they could be 
-- done using hardware approaches (e.g., using a resister-capacitor)
-- or software-based ones.  In a software approach, we could detect
-- a button transition and sample it again at a later point in time,
-- which is at least a few milliseconds long (like 10 ms); if the
-- button's state had remained the same (i.e., it was "stable"), we
-- output that the button was "pressed" once. 
--     Be aware that other problems arising from external, wired
-- interfaces might still apply: we had better accounted for
-- metastability and asynchnorized clock domains.




-- --------------------------------------------------------------------
-- END OF FILE: debouncer.vhd
-- --------------------------------------------------------------------