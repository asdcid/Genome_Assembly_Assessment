#!/usr/bin/python

import cStringIO
import copy
import logging
import os.path
import sys

ALL_LETTERS = 'ATGC'

class BasicStats:

    def __init__(self, path):
        self.path  = path
        self.seqs  = {}
        self.loadSeqs()

    def loadSeqs(self):
        logging.info('Loading fastafile %s' % self.path)
        # loads sequences in StringIO buffers
        handle = open(self.path)
        for line in handle:
            line = line.strip()
            if not line:
                continue
            if line[0] == '>':
                name = line[1:]
                if name in self.seqs:
                    logging.error('Dupplicated sequence name: %s' % name)
                    sys.exit(1)
                self.seqs[name] = cStringIO.StringIO()
            elif name:
                self.seqs[name].write(line)
        handle.close()
        # get sequences as strings
        for name in self.seqs:
            # Uppercase all sequences
            tmp = self.seqs[name].getvalue().upper()
            self.seqs[name].close()
            self.seqs[name] = tmp
        # (re-)initialise stats
        self.initStats()

    def initStats(self):
        self.sizes        = []
        self.sizesCumSum  = []
        self.totalSize    = 0
        self.n50          = 0
        self.letterCounts = {}

    def getSizes(self):
        if not self.sizes:
            for name in self.seqs:
                self.sizes.append(len(self.seqs[name]))
        self.sizes.sort()
        return self.sizes

    def getSizesCumSum(self):
        if not self.sizesCumSum:
            sizes = self.getSizes()
            self.sizesCumSum = copy.copy(sizes)
            for i in xrange(1, len(sizes)):
                self.sizesCumSum[i] += self.sizesCumSum[i - 1]
        return self.sizesCumSum

    def getTotalSize(self):
        if not self.totalSize:
            cumSum         = self.getSizesCumSum()
            self.totalSize = cumSum[-1]
        return self.totalSize

    def getMedianSize(self):
        sizes = self.getSizes()
        return sizes[len(sizes) / 2]

    def getMeanSize(self):
        return float(self.getTotalSize()) / len(self.getSizes())

    def getLetterCounts(self):
        if not self.letterCounts:
            # Initialise letter counts dictionary
            for i in ALL_LETTERS:
                self.letterCounts[i] = 0
            self.letterCounts['N'] = 0
            # Count letters in each sequence
            for name in self.seqs:
                # Handle ATGC
                totATGC = 0
                for i in ALL_LETTERS:
                    count                 = self.seqs[name].count(i)
                    totATGC              += count
                    self.letterCounts[i] += count
                # Handle N
                self.letterCounts['N'] += len(self.seqs[name]) - totATGC
        return self.letterCounts

    def getLetterCountsStr(self):
        letterCounts = self.getLetterCounts()
        l = []
        tot = sum(letterCounts.values())
        for i in letterCounts:
            s = '(%s : %.2f%%)' % (i, (100. * letterCounts[i] / tot))
            l.append(s)
        return ' '.join(l)

    def getPercentNs(self):
        letterCounts = self.getLetterCounts()
        tot = sum(letterCounts.values())
        return (100. * letterCounts['N']) / tot

    def getDeciles(self):
        sizes = self.getSizes()
        dec   = []
        for i in xrange(1, 10):
            dec.append(sizes[int((float(i) * len(sizes)) / 10)])
        return dec

    def getSizePerDecile(self):
        sizes = self.getSizes()
        decSizes = []
        interval = float(len(sizes)) / 10
        for i in xrange(1, 11):
            start = int((i - 1) * interval)
            end   = int(i * interval)
            decSizes.append(sum(sizes[start:end]))
        return decSizes

    def getLargestContig(self):
        sizes = self.getSizes()
        return sizes[-1]

    def getN50(self):
        if not self.n50:
            # TODO: A dichotomic search would be faster
            sizes  = self.getSizes()
            cumSum = self.getSizesCumSum()
            total  = self.getTotalSize()
            half   = total / 2
            for i in xrange(len(cumSum)):
                if cumSum[i] >= half:
                    self.n50 = sizes[i]
                    break
        return self.n50

    def listToStr(self, l):
        return ' '.join([str(x) for x in l])

    def printAllStats(self, handle):
        handle.write('Total size    : %d mb (%d bp)\n'% ((self.getTotalSize() / 1000.0) / 1000.0, self.getTotalSize()))
        handle.write('Nb sequences  : %d\n'   % len(self.seqs))
        handle.write('Deciles       : %s\n'   % self.listToStr(self.getDeciles()))
        handle.write('Deciles sizes : %s\n'   % self.listToStr(self.getSizePerDecile()))
        handle.write('Median size   : %f kb\n'   % (self.getMedianSize() / 1000.0))
        handle.write('Mean size     : %f kb\n'   % (self.getMeanSize() / 1000.0))
        handle.write('N50 size      : %d kb\n'   % (self.getN50() / 1000.0))
        handle.write('Largest       : %d kb\n'   % (self.getLargestContig() / 1000.0))
        handle.write('Letter counts : %s\n'   % self.getLetterCountsStr())
        handle.write('Percent Ns    : %f%%\n' % self.getPercentNs())

def main():
    logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s %(message)s')
    logging.debug('Starting ...')

    if len(sys.argv) < 2:
        logging.error('Usage: %s FILE' % os.path.basename(sys.argv[0]))
        sys.exit(1)

    stats = BasicStats(sys.argv[1])
    stats.printAllStats(sys.stdout)
    logging.debug('All Done')

if __name__ == '__main__':
    main()

