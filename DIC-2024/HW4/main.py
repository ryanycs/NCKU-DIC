#!/usr/bin/python3

#
# Golden data generator for MPQ
#

class Heap:
    def __init__(self, arr):
        self.arr = [0, *arr]

    def build(self):
        for i in range(len(self.arr) >> 1, 0, -1):
            self._heapify(i)

    def pop(self):
        if (len(self.arr) < 1):
            return

        top = self.arr[1]
        self.arr[1] = self.arr[-1]
        self.arr.pop()
        self._heapify(1)

        return top
    
    def increase(self, i, value):
        i = i + 1
        if value < self.arr[i]:
            return

        self.arr[i] = value
        while (i > 1 and self.arr[i >> 1] < self.arr[i]):
            self.arr[i], self.arr[i>>1] = self.arr[i>>1], self.arr[i]
            i = i >> 1

    def insert(self, value):
        self.arr.append(value)
        self.increase(len(self.arr) - 2, value)

    def _heapify(self, i: int):
        max_idx = i
        left = i << 1
        right = i << 1 | 1

        if (left <= len(self.arr) - 1 and self.arr[left] > self.arr[max_idx]):
            max_idx = left

        if (right <= len(self.arr) - 1 and self.arr[right] > self.arr[max_idx]):
            max_idx = right

        if (max_idx != i):
            self.arr[i], self.arr[max_idx] = self.arr[max_idx], self.arr[i]
            self._heapify(max_idx)

if __name__ == "__main__":
    t = input("Select the test case and press Enter: ")
    t2 = "" if t == "3" else t

    arr = []
    with open(f"./dat/P{t}/pat{t2}.dat", "r") as f:
        while True:
            s = f.readline()
            if (s == ""):
                break
            arr.append(int(s.split()[0], 16))

    cmd = []
    with open(f"./dat/P{t}/cmd{t2}.dat", "r") as f:
        while True:
            s = f.readline()
            if (s == ""):
                break
            cmd.append(s.split()[0])

    index = []
    with open(f"./dat/P{t}/index{t2}.dat", "r") as f:
        while True:
            s = f.readline()
            if (s == ""):
                break
            index.append(int(s.split()[0], 16))

    value = []
    with open(f"./dat/P{t}/value{t2}.dat", "r") as f:
        while True:
            s = f.readline()
            if (s == ""):
                break
            value.append(int(s.split()[0], 16))

    heap = Heap(arr)

    for i in range(len(cmd)):
        match (cmd[i]):
            case "000":
                print("Build")
                heap.build()
                print(heap.arr[1:])
                print()
            case "001":
                print("Pop")
                heap.pop()
                print(heap.arr[1:])
                print()
            case "010":
                print(f"Increase A[{index[i] + 1}] to {value[i]}")
                heap.increase(index[i], value[i])
                print(heap.arr[1:])
                print()
            case "011":
                print(f"Insert {value[i]}")
                heap.insert(value[i])
                print(heap.arr[1:])
                print()

    output = [hex(x).lstrip("0x") for x in heap.arr[1:]]

    with open(f"./golden{t2}.dat", "w") as f:
        for i in range(len(output)):
            f.write(f"{output[i]:>2}\n")
