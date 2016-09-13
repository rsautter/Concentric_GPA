import numpy
from libc.math cimport pow, fabs, sqrt
from scipy.spatial import Delaunay as Delanuay

cimport numpy


cdef class GPA:
    cdef public float[:,:] mat,gradient_dx,gradient_dy,gradient_asymmetric_dy,gradient_asymmetric_dx
    cdef public float cx, cy, r, Ga
    cdef public int n_points, n_edges
    cdef public numpy.ndarray triangulation_points
    cdef public object triangles
    cdef int rows, cols

    #@profile
    def __init__(self, mat):
        # setting matrix,and calculating the gradient field
        self.mat = mat
        self._setGradients()

        # default value
        # calculated using gradient ascendant, if not specified
        self.cx = -1
        self.cy = -1
        self.r = -1

    def setPosition(self, float cx, float cy):
        self.cx = cx
        self.cy = cy

    def _setGradients(self):
        cdef int w, h
        cdef float maxGrad
        gx, gy = numpy.gradient(self.mat)
        w, h = len(gx[0]),len(gx)
         # gradient normalization
        maxGrad = numpy.max((gx**2.0+gy**2.0)**0.5)
        for i in range(h):
            for j in range(w):
                gx[i,j] = gx[i,j] / maxGrad
                gy[i,j] = gy[i,j] / maxGrad
        self.gradient_dx=numpy.array([[gx[j, i] for i in range(w) ] for j in range(h)],dtype=numpy.float32)
        self.gradient_dy=numpy.array([[gy[j, i] for i in range(w) ] for j in range(h)],dtype=numpy.float32)
        #para remover:
        

        # copying gradient field to asymmetric gradient field
        self.gradient_asymmetric_dx = numpy.array([[gx[j, i] for i in range(w) ] for j in range(h)],dtype=numpy.float32)
        self.gradient_asymmetric_dy = numpy.array([[gy[j, i] for i in range(w) ] for j in range(h)],dtype=numpy.float32)

        



    def _update_asymmetric_mat(self,int[:] index_dist,int[:,:] dists,float tol,int rad_tol):
        cdef int ind, lx, px, py
        cdef int tol_angular = rad_tol / 2
        cdef float sx,sy,prx,pry
        cdef int[:] x, y

        tol_angular = rad_tol / 2
        for ind in range(0, len(index_dist), 1):
            x2, y2 =[], []
            for py in range(self.rows):
                for px in range(self.cols):
                    if (fabs(dists[py, px]-ind) <= fabs(tol_angular)):
                        x2.append(px)
                        y2.append(py)
            x, y =numpy.array(x2,dtype=numpy.int32), numpy.array(y2,dtype=numpy.int32)
            lx = len(x)
            # compare each point in the same distance
            for i in range(lx):
                sx = self.gradient_asymmetric_dx[y[i], x[i]]
                sy = self.gradient_asymmetric_dy[y[i], x[i]]
                if sqrt(pow(sx, 2.0) + pow(sy, 2.0)) <= tol:
                    self.gradient_asymmetric_dx[y[i], x[i]] = 0.0
                    self.gradient_asymmetric_dy[y[i], x[i]] = 0.0
                for j in range(lx):
                    if(sqrt(pow(y[i]-y[j],2.0)+pow(x[i]-x[j],2.0)) == 0.0):
                        continue
                    prx = fabs(y[i]-y[j])/sqrt(pow(y[i]-y[j],2.0)+pow(x[i]-x[j],2.0))
                    pry = fabs(x[i]-x[j])/sqrt(pow(y[i]-y[j],2.0)+pow(x[i]-x[j],2.0))
                    dx = (sx + self.gradient_dx[y[j]][x[j]])*prx
                    dy = (sy + self.gradient_dy[y[j]][x[j]])*pry
                    if (dx ** 2 + dy ** 2) ** 0.5 <= tol:
                        self.gradient_asymmetric_dx[y[i], x[i]] = 0.0
                        self.gradient_asymmetric_dy[y[i], x[i]] = 0.0
                        self.gradient_asymmetric_dx[y[j], x[j]] = 0.0
                        self.gradient_asymmetric_dy[y[j], x[j]] = 0.0
                        break


#    def _resample(self,int n):
#        cdef:
#            float[:,:] nMat
#            float scale
#            int i, j, px, py
#            int w, h
#        w, h =  len(self.mat[0]), len(self.mat)
#        nMat = numpy.array([[0.0 for i in range(n)] for j in range(n)],dtype=numpy.float32)
#        scale = 2.0 * self.r / n
#        for i in range(w):
#            for j in range(h):
#                px = int(self.cx+scale*(i-n/2))
#                py = int(self.cy+scale*(j-n/2))
#                nMat[j, i] = self.mat[py, px]
#        self.cx = n/2
#        self.cy = n/2
#        self.r = n/2
#        self.mat = nMat

    #@profile
    def evaluate(self,float tol,int ang_tol, nbins = -1):
        self._setGradients()
        cdef int[:] i
        cdef int maior,menor, r, c, nuniq

        self.cols = len(self.mat[0])
        self.rows = len(self.mat)

        if(nbins <0):
            nbins = max(self.cols,self.rows)
        if(self.r< 0.0):
            self.r = int(max(self.cols,self.rows)/2)

        cdef numpy.ndarray dists = numpy.array([[int(sqrt(pow(x-self.cx, 2.0)+pow(y-self.cy, 2.0))) for x in range(self.cols)] for y in range(self.rows)])
        cdef numpy.ndarray uniq = numpy.unique(dists)
        #for r in range(self.rows):
        #    for c in range(self.cols):
        #        if (dists[c, r] >= self.r):
        #            self.gradient_dx[c, r] = 0.0
        #            self.gradient_dy[c, r] = 0.0
        #            self.gradient_asymmetric_dx[c, r] = 0.0
        #            self.gradient_asymmetric_dy[c, r] = 0.0



        #normalizando:
        #nuniq = len(uniq)
        #maior, menor = 0, 0
        #for r in  range(nuniq):
        #    if (maior < uniq[r]) or (r==0):
        #        maior = uniq[r]
        #    if (menor > uniq[r]) or (r==0):
        #        menor = uniq[r]

        #dists =(dists-menor)*(nbins)/(maior-menor)
        #dists = dists.astype(int)
        uniq = numpy.unique(dists)

        # removes the symmetry in gradient_asymmetric_dx and gradient_asymmetric_dy:
        self._update_asymmetric_mat(uniq.astype(dtype=numpy.int32), dists.astype(dtype=numpy.int32), tol, ang_tol)

        # triangulating the middle points of the vectors
        self._generate_triangulation_points(tol)
        return self.Ga

    #@profile
    def _generate_triangulation_points(self,float tol):
        cdef int w, h, i, j
        cdef float mod

        triangulation_points = []
        for i in range(self.rows):
            for j in range(self.cols):
                mod = (self.gradient_asymmetric_dx[i, j]**2+self.gradient_asymmetric_dy[i, j]**2)**0.5
                if mod > tol:
                    triangulation_points.append([j+0.5*self.gradient_asymmetric_dx[i, j], i+0.5*self.gradient_asymmetric_dy[i, j]])
        self.triangulation_points = numpy.array(triangulation_points)
        self.n_points = len(self.triangulation_points)
        if self.n_points < 3:
            self.n_edges = 0
            self.Ga = 0
        else:
            self.triangles = Delanuay(self.triangulation_points)
            neigh = self.triangles.vertex_neighbor_vertices
            self.n_edges = len(neigh[1])/2
            self.Ga = float(self.n_edges-self.n_points)/float(self.n_points)
