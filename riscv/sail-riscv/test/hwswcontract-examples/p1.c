

unsigned int array1_size = 16;
int array1[16] = { 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16 };
int array2[16];
int temp = 0; /* Used so compiler won't optimize out victim_function() */
int x = 18;

int main()
{
	if (x < array1_size) {
        temp += array1[x];
        temp *= 64;
        temp &=array2[temp];
    }

}
