
#!/usr/bin/env python
# coding: utf-8

# In[1]:


from pynq import Overlay


# In[3]:


ol=Overlay("pwm_test.bit")

print(ol.ip_dict.keys())


# In[4]:


from pynq import MMIO
import time


# In[13]:


address =ol.ip_dict['PWM_controller_0']['phys_addr'] 


# In[14]:


print(address)


# In[ ]:


range_size=0x1000

pwm_ip=MMIO(address, range_size)
x=0

while x<1:
    try:
        print("Satarting PWM Fading...")

        for i in range(0,255,100):
            pwm_ip.write(0,i)
            time.sleep(0.5)

        for i in range(255,0,-100):
            pwm_ip.write(0,i)
            time.sleep(0.5)
    except KeyboardInterrupt:
        pwm_ip.write(0,0)
        print("stopped...")


Displaying PWM_ip.py.
