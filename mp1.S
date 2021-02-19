
.data					# section declaration

        # Useful offset constants for accessing members of a 
        # struct mp1_blink_struct structure
        LOCATION   = 0    
        ON_CHAR    = 2
        OFF_CHAR   = 3 
        ON_LENGTH  = 4
        OFF_LENGTH = 6
        COUNTDOWN  = 8
        STATUS     = 10
        NEXT       = 12

        STRUCT_SIZE = 16

# Pointer to head of list (initialized to NULL)
mp1_list_head:
        .long   0

.text					# section declaration

# Export the function symbol names

.global mp1_rtc_tasklet
.global mp1_ioctl

# void mp1_poke(void);
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX
mp1_poke:
        
	movl    vmem_base_addr(,1),%edx
	movb    %cl,(%edx,%eax,1)
	ret

mp1_rtc_tasklet:
        subl $4, %esp 
        movl %ebp, (%esp) 
        movl %esp, %ebp 

        # need to save registers of caller func 
        subl $4, %esp 
        movl %esi, (%esp)

        andl $0, %edx  # clear edx 

        subl $4, %esp 
        movl %esi, (%esp)

        movl (mp1_list_head), %esi # edx stores head of ll now 
        movl %esi, %edx

        movl (%esp), %esi 
        addl $4, %esp  

search_in_ll: 
        cmpl $0, %edx # check if head node is null 
        je exit_from_tasklet 

        decl COUNTDOWN(%edx) 

        
        cmpw $0, COUNTDOWN(%edx)  # check if countdown has reached 0 
        jg countdown_over_zero

        # at this point we know countdown is 0 
        movw STATUS(%edx), %si # store status attrib of edx in di reg 
        not %si # opposite the status 
        and $0x1, %esi # bit masking 

set_reg_ll: 
        subl $4, %esp 
        movl %eax, (%esp)

        movl %esi, %eax 
        movl %eax, %esi 

        movl (%esp), %eax
        addl $4, %esp 

        movw %si, STATUS(%edx) # put the new status into edx's status
        
        subl $4, %esp 
        movw %di, (%esp)
        
        movw %si, %di
        andw %di, %di 

        cmp $0, %di  
        je off_char_tasklet 
        
        movw (%esp), %di 
        addl $4, %esp 

on_char_tasklet: 
        movb ON_CHAR(%edx), %cl # store on char on cl reg 

        subl $4, %esp 
        movl %edi, (%esp) 
        
        movw ON_LENGTH(%edx), %di # change countdown to be on_length 
        jmp set_up_on_off_chars 



off_char_tasklet: 
        movb OFF_CHAR(%edx), %cl # put the off char on cl reg 

        subl $4, %esp 
        movl %edi, (%esp) 

        movw OFF_LENGTH(%edx), %di # set countdown based on off_length now. This is in bx for now


set_up_on_off_chars: 
        andl $0, %eax # clear eax reg 

        movw LOCATION(%edx), %ax # put location attrib of edx in ax reg 
        shlw $1, %ax # location gets shifted left by 1 bit 

        subl $4, %esp 
        movl %edx, (%esp) # edx is arg for mp_1 poke call 

        call mp1_poke
        
        movl (%esp), %edx 
        addl $4, %esp   # put by edx's orig value 

        movw %di, COUNTDOWN(%edx) # store bx into edx's countdown attrib. bx was previously filled with the right countdown attrib
        
        movl (%esp), %edi 
        addl $4, %esp  


countdown_over_zero: 
        movl NEXT(%edx), %edx # move to next node in ll 
        jmp search_in_ll # continu traversing ll 


exit_from_tasklet: 
        # set back registers of the caller func 
         
        movl (%esp), %edi 
        addl $4, %esp 
        
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        movl (%esp), %ebp 
        addl $4, %esp 
        ret 

mp1_ioctl:
        movl 8(%esp), %ecx  # put arg into ecx reg. arg is the cmd value which is the value for what function to use 
        cmpl $4, %ecx # ecx value can only be bw 0-3. 
        jae value_of_cmd_error # cmd value is incorrect ERROR 
        jmp *jump_table(, %ecx, 4)

value_of_cmd_error: 
        movl $-1, %eax 
	ret

mp1_ioctl_add:

        # epilogue 
        subl $4, %esp 
        movl %ebp, (%esp)  # push old stack pointer to stack 
        movl %esp, %ebp # ebp = esp 

        subl $4, %esp 
        movl %edx, (%esp)
setLreg: 
        andl $0, %edx 
        movl 8(%ebp), %edx # ecx <- M[ebp + 8] Puts 1st arguement into ecx. this arg is the user struct ptr

        subl $4, %esp 
        movl %edi, (%esp)
         
        movl %edx, %edi 
        andl %edi, %edi 
        cmpl $0, %edi 
        # ANDs ecx and ecx to see if they equal 0 which wud mean address is NULL 
        je error_situation # if equal that means ZF was set, so addr is NULL 
        movl (%esp), %edi 
        addl $4, %esp 

        movl (%esp), %edx 
        addl $4, %esp 
        
push_args_add: 
        subl $4, %esp 
        movl %esi, (%esp) # good practice bc we'll use this register later so we save callee register now

        movl mp1_list_head, %edx # edx now has the address of the LL head 

        subl $4, %esp 
        movl $STRUCT_SIZE, (%esp)  # pushing our argument to the top of stack. Malloc will use this to allocate STRUCT_SIZE bytes

        call mp1_malloc # calls malloc function 
allocation_done: 
        subl $4, %esp 
        movw %di, (%esp)

        movw %ax, %di 
        andw %di, %di 
        cmp $0, %di 
         #  ax is the return value of malloc (a pointer (addr)) which we check to see if it errored 
        je error_need_to_open_memory
        movw (%esp), %di 
        addl $4, %esp 

        movl 8(%ebp), %ecx  # store our user struct arg into register ecx 
        movl %eax, %esi # esi = eax, where eax is the memory location of the new allocated chunk of space malloc made. eax reg is where that pointer is stored

        subl $4, %esp 
        movl %esi, (%esp) # push esi to stack (saving it for future use)

        subl $4, %esp 
        movl $STRUCT_SIZE, (%esp)  # push struct_size to stack 

        subl $4, %esp 
        movl %ecx, (%esp) # location of user struct 

        subl $4, %esp 
        movl %esi, (%esp) # location of allocated memory starting location. Here once we push this and then enter and exit copy function, esi will not be saved
        call mp1_copy_from_user  # copies user struct entirely to newly allocated space 

        addl $12, %esp # get 2nd argument 
        
        movl (%esp), %esi 
        addl $4, %esp  # restore esi. Esi now still has the starting location of malloc-ed space

        subl $4, %esp 
        movw %di, (%esp)

        movw %ax, %di 
        andw %di, %di 
        cmp $0, %di 
        # checking for error 
        jne error_need_to_open_memory # if copy_from_user returns anything BUT 0 that's an error 
        
        movw (%esp), %di 
        addl $4, %esp 

        movw LOCATION(%esi), %ax # put location attribute of blink struct into ax 
        cmpw $2000, %ax # check if ax is less than 2000, in valid range 
        jae error_need_to_open_memory # error occured bc location is outside valid range 

        # we still didn't make the LL. We're going to put it into our malloc-ed memory now
next_ptr_for_list:

        movl (mp1_list_head), %edx  # %edx <- M[mp1_list_head]
        movl %edx, NEXT(%esi) # setting up next ptr for head of LL M[%esi + NEXT] <- edx

        movw ON_LENGTH(%esi), %ax # store length value in ax 
        movw %ax, COUNTDOWN(%esi) # store length (ax) in countdown so that length = countdown

        movw $1, STATUS(%esi) # puts 1 into status attribute 

        # setting start location of malloc chunk to be the head location 
        movl %esi, (mp1_list_head) # set esi as new head of ll.  M[mp1_list_head] <- esi

        movw LOCATION(%esi), %ax # put location attribute into ax 

        shlw $1, %ax # shift location attirbute left by 1 bit 
        movb ON_CHAR(%esi), %cl  
        call mp1_poke

        movl (%esp), %esi 
        addl $4, %esp 

        # epilogue 
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        
        movl (%esp), %ebp 
        addl $4, %esp 

	ret

error_need_to_open_memory: # error handling in general and error handling memory leaks 
        subl $4, %esp 
        movl %eax, (%esp) # argument to mp1_free  

        call mp1_free # free some memory 

        movl $-1, %eax # we had an error with allocation so we put -1 in return register 
        
        movl (%esp), %ecx 
        addl $4, %esp  # put back values of caller registers 
        
        movl (%esp), %esi 
        addl $4, %esp 

set_esp_val: 
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        movl (%esp), %ebp 
        addl $4, %esp 
        ret 
        
mp1_ioctl_remove:
        # prologue 
        subl $4, %esp 
        movl %ebp, (%esp)

        movl %esp, %ebp 

        movl 8(%ebp), %edx # put argument passed to this func in edx 
        call traverser # linked list traversal function 

        subl $4, %esp 
        movw %di, (%esp) 

        movw %ax, %di 
        andw %di, %di 
        cmp $0, %di 
           # check what the return value is (eax) 
        je error_situation   # error out bc we didn't find the node since ax was null 
        
        movw (%esp), %di 
        addl $4, %esp 
        
        # need to cleanly remove node at this point 
        subl $4, %esp 
        movl %edi, (%esp)

        movl %ecx, %edi 
        andl %edi, %edi 
        cmpl $0, %edi 
         # check if ecx is the head node 
        je replace_head
        
        movl (%esp), %edi 
        addl $4, %esp 

        # not head so we do regular remove here
        subl $4, %esp 
        movl %eax, (%esp)

        movl NEXT(%eax), %edx # save eax's next ptr in edx 
        movl %edx, NEXT(%ecx)  # make ecx's next be edx (formerly eax's next)
        call mp1_free # this will get rid of the node at eax 
        # visually ecx -> eax -> edx 
        # we know ecx is before eax bc in the traversal func ecx always stored the 
        # previosu node ptr 
        # Result: ecx -> edx after mp1_free 

        
        andl $0, %eax  # return 0 for successful remove 

        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        
        movl (%esp), %ebp 
        addl $4, %esp 
	ret

replace_head: 
        subl $4, %esp 
        movl %eax, (%esp) # we push eax into stack cuz mp1_free will use this arg to deallocate it 
        
        movl NEXT(%eax), %edx # get the new head and put it into edx, since we're removing current head
        movl %edx, mp1_list_head  # mp1_list_head = edx 

        call mp1_free # free up memory 
        andl $0, %eax  # return value will be 0 bc we succesfully removed 
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        
        movl (%esp), %ebp 
        addl $4, %esp 
        ret 
        
mp1_ioctl_find:
        subl $4, %esp 
        movl %ebp, (%esp)

        movl %esp, %ebp 

        movl 8(%ebp), %ecx  # put argument into ecx register 
        movw LOCATION(%ecx), %dx # get location attribute and put in dx 

        cmpw $2000, %dx # ensure dx is within range 
        jae error_situation # if above or equal to 2000, then we have an error 

        subl $4, %esp 
        movl %ecx, (%esp) # save ecx
        # traverser's argument was dx which we loaded in earlier.
        call traverser # look for this node 

check_null:        
        movl (%esp), %ecx 
        addl $4, %esp  # put back ecx's orig value in register 

        subl $4, %esp 
        movl %edi, (%esp)

        movl %eax, %edi 
        andl %edi, %edi 
        cmp $0, %edi 
           # check if return value was null 
        je error_situation # error 
        
        movl (%esp), %edi 
        addl $4, %esp 

        subl $4, %esp 
        movl %ebx, (%esp)

copy_struct_happen: 
        movl $STRUCT_SIZE, %ebx 
        subl $4, %esp 
        movl %ebx, (%esp)

          # args for copy functions 
        subl $4, %esp 
        movl %eax, (%esp)  # this is the addr of the found node w the same location attrib (from)
        
        subl $4, %esp 
        movl %ecx, (%esp) # this is the addr of the node we're given (to)
        
        call mp1_copy_from_user # copy eax into ecx entirely 

        andl $0, %eax # put 0 in eax to indicate success 
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        
        movl (%esp), %ebp 
        addl $4, %esp 
	ret

mp1_ioctl_sync:
        subl $4, %esp 
        movl %ebp, (%esp)

        movl %esp, %ebp 

        subl $4, %esp 
        movl %edi, (%esp) # # need to save register of caller func 
        
        subl $4, %esp 
        movl %esi, (%esp)

        movl 8(%ebp), %edi # put our argument into edi 
        movl %edi, %esi # put a copy of edi into esi cuz our argument is actually 2 args

        shrl $16, %esi 
        cmpw $2000, %si # check if location is valid or not 
        jae error_situation
loc_valid: 
        cmpw $2000, %di # test if location is valid or not for other argument 
        jae error_situation

        movw %di, %dx # put di into dx bc dx will be the arg for our traversal next 
        call traverser

        subl $4, %esp 
        movl %edi, (%esp)

        movl %eax, %edi 
        andl %edi, %edi 
        cmpl $0, %edi 
         # test to see if traverser function returned a null addr 
        je sync_error
        
        movl (%esp), %edi 
        addl $4, %esp  

        # came out cleanly from traverser, we'll store the addr of the struct we found 
        movl %eax, %ecx # ecx now has the first struct 

        movw %si, %dx # putting second arg into dx. dx is arg for traversal which we do now 
        subl $4, %esp 
        movl %ecx, (%esp) # need to save ecx of caller before starting traversal 

        call traverser 
        
        movl (%esp), %ecx 
        addl $4, %esp 

        subl $4, %esp 
        movl %edi, (%esp)

        movl %eax, %edi 
        andl %edi, %edi 
        cmpl $0, %edi 
          # test if traverser found an addr or not. see if its null 
        je sync_error
        
        movl (%esp), %edi 
        addl $4, %esp 
hold_other_struct: 
        movl %eax, %edx # store second struct we found in edx. So now we have
        # ecx holding 1st struct and edx holding 2nd struct 

        andl $0, %eax # clears eax register 

        # making the first and second struct attributes the same
        jmp load_length 

        andl $0, %eax # clear eax register 

        movw COUNTDOWN(%edx), %ax # save edx's countdown in ax reg  
        movw %ax, COUNTDOWN(%ecx) # make ecx's countdown same as that of edx 

        andl $0, %eax # clear eax register 

        movw STATUS(%edx), %ax # save edx's status in ax reg 
        movw %ax, STATUS(%ecx) # make ecx's status be same as that of edx 

        subl $4, %esp 
        movw %di, (%esp)

        movw %ax, %di 
        andw %di, %di 
        cmp $0, %di 
         # ax has the status now. Check if its the off_char on the on_char
        je it_is_off_char   # if status = 0 then we shud execute off char code 
        movw (%esp), %di 
        addl $4, %esp 

it_is_on_char: 
        movb ON_CHAR(%ecx), %cl # put on_char on cl reg 
        jmp decided_on_off_char


it_is_off_char: 
        movb OFF_CHAR(%ecx), %cl  # put the off char on cl reg 

decided_on_off_char: 
        andl $0, %eax # clear eax reg 

        movw LOCATION(%ecx), %ax # load location of ecx into ax 
        shlw $1, %ax # shift ax left 1 bit 
        call mp1_poke 

        movl (%esp), %esi 
        addl $4, %esp  # restoring caller registers (cleanup)
        movl (%esp), %edi 
        addl $4, %esp 
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        movl (%esp), %ebp 
        addl $4, %esp 
	ret

sync_error: 
        movl (%esp), %esi 
        addl $4, %esp   # restore caller registers 
        movl (%esp), %edi 
        addl $4, %esp 
        movl $0, %eax   # error 
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        movl (%esp), %ebp 
        addl $4, %esp 
        ret 


traverser: 
        subl $4, %esp 
        movl %ebp, (%esp)

        movl %esp, %ebp 

        subl $4, %esp 
        movl %ebx, (%esp) # save callee register. This reg will be used in loop so we'll save it here 
        
        movl mp1_list_head, %eax # put head pointer into eax 
        andl $0, %ecx # this will 0 out the ecx register via xor 

loop: 
        subl $4, %esp 
        movl %edi, (%esp)

        movl %eax, %edi 
        andl %edi, %edi 
        cmpl $0, %edi 
         # check if we have an actual head pointer thats not null 
        je error_no_addr 
        movl (%esp), %edi 
        addl $4, %esp  
continue: 
        movw LOCATION(%eax), %bx # save location attribute into bx 
        cmpw %bx, %dx  # dx (or edx) has the location of the arg1 (the node we need to remove)
        # the above will compare to see if location bx and dx are the same 

        je found_node # node was found so I can return and stop traversal 

        # this code moves our pointer to next node in list 
        movl %eax, %ecx # ecx = eax; ecx is holding prev node's location 
        movl NEXT(%eax), %eax # saying take the next node and set it to the current node (eax)
        jmp loop # continue traversal 


found_node: 
        movl (%esp), %ebx 
        addl $4, %esp  # restore ebx register (note ebx and bx are the same, just e makes the reg extended)
        movl   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        movl (%esp), %ebp 
        addl $4, %esp 
        ret 

load_length: 
        pushl %ebp 
        movl %esp, %ebp 

        movw ON_LENGTH(%edx), %ax # put length attribute of edx into eax 
        movw %ax, ON_LENGTH(%ecx) # make length of ecx (1st structure) be same as length of 2nd structure 

        andl $0, %eax # clear eax register 

        movw OFF_LENGTH(%edx), %ax # save off_length attrib of 2nd struct edx in ax 
        movw %ax, OFF_LENGTH(%ecx) # make ecx's off_length be same as edx's off_length 

        movl %ebp, %esp 
        popl %ebp 
        ret


error_no_addr:
        movl (%esp), %ebx 
        addl $4, %esp  # put ebx's orig reg value back into ebx 
cleanup:        
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        movl (%esp), %ebp 
        addl $4, %esp 
        ret 


error_situation: 
        movl $-1, %eax  # put -1 in for return value as eax stores return value 
        
        mov   %ebp, %esp     # esp = ebp,  mov  esp,ebp in Intel syntax
        movl (%esp), %ebp 
        addl $4, %esp  
        ret 

jump_table: 
.long mp1_ioctl_add, mp1_ioctl_remove, mp1_ioctl_find, mp1_ioctl_sync

.end
